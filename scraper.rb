#!/usr/bin/env ruby

require 'nokogiri'
require 'json'

FY_RANGE = 10..15
IS_BOLDED_LABEL = -> (cur) { !!cur.first_element_child }
PRIOR_FUNDING_TABLE_COLS = ['Allotments', 'Spent', 'Enc/ID-Adv', 'Pre-Enc', 'Balance']
MILESTONES = [:environmental_approvals, :design_start, :design_complete,
              :construction_start, :construction_complete, :closeout]
IMAGES_DIR = 'images/'
OUTPUT_FILE = 'data.json'

def scrape_title(page)
    cur = page.at("text:contains('Agency:')").previous_element
    title = cur.text.strip

    if cur.previous_element && cur.previous_element.text != ' ' then
        title = cur.previous_element.text + title
    end

    return title
end

def scrape_image(page)
    cur = page.at("image")

    if cur then
        filename = cur['src'].split('/')[-1]
        if File.exist? IMAGES_DIR + filename then
            return filename
        end
    end
end

def scrape_field(page, field)
    cur = page.at("text:contains('#{field}:')")

    if cur then
        cur = cur.next_element
        if !IS_BOLDED_LABEL.call(cur) then
            return cur.text.strip
        end
    end
end

def scrape_field_single_el(page, field)
    cur = page.at("text:contains('#{field}:')")

    if cur then
        return cur.css('> text()').text.strip
    end
end

def scrape_paragraph(page, heading)
    scrape_paragraph_with_end_test(page, heading, &IS_BOLDED_LABEL)
end

def scrape_paragraph_with_end_test(page, heading, &end_test)
    cur = page.at("text:contains('#{heading}:')")

    if cur then
        cur = cur.next_element
        paragraph = ""
        until end_test.call(cur) do
            l = cur.text
            paragraph += l
            cur = cur.next_element
        end

        return paragraph.strip
    end
end

def scrape_funding_table(page, type, fy)
    type_sym = type.downcase.to_sym
    cur = page.at("b:contains('#{type}')").parent
    rows = []

    while IS_BOLDED_LABEL.call(cur) do cur = cur.next_element end

    until cur.text.include? 'TOTALS' do
        row = { :prior_funding => {}, :proposed_funding => {} }
        row[type_sym] = cur.text.strip

        x = cur['left'].to_i

        cur = cur.next_element
        while cur['left'].to_i == x do
            row[type_sym] += " " + cur.text.strip
            cur = cur.next_element
        end

        for col in PRIOR_FUNDING_TABLE_COLS do
            row[:prior_funding][col] = cur.text.gsub(/\D/,'').to_i
            cur = cur.next_element
        end

        for yy in fy..(fy + 5) do
            row[:proposed_funding]["FY 20#{yy}"] = cur.text.gsub(/\D/,'').to_i
            cur = cur.next_element
        end

        unless cur['left'].to_i == x then cur = cur.next_element end

        rows.push(row)
    end

    return rows
end

def scrape_milestones_table(page)
    cur = page.at("b:contains('Milestone Data')")

    if cur then
        milestones = {}
        cur = cur.parent.next_element
        div_x = cur['left'].to_i + cur['width'].to_i

        cur = cur.next_element.next_element

        for milestone in MILESTONES do
            dates = {}

            row_y = cur['top'].to_i
            cur = cur.next_element

            while (cur['top'].to_i - row_y).abs < 5 do
                if cur.text != ' ' then
                    if cur['left'].to_i < div_x then
                        dates[:projected] = cur.text.strip
                    else
                        dates[:actual] = cur.text.strip
                    end
                end

                cur = cur.next_element
            end

            milestones[milestone] = dates
        end

        return milestones
    end
end

projects = []

for fy in FY_RANGE do
    path = "xml/fy#{fy}.xml"
    fi = File.open(path)
    doc = Nokogiri::XML(fi)

    for page in doc.css('page') do
        unless page.text.include? 'Project No:' then next end

        data = {}

        data[:cip_fy] = fy

        data[:title] = scrape_title(page)
        puts data[:title]
        data[:image] = scrape_image(page)
        data[:agency] = scrape_field(page, 'Agency')
        data[:implementing_agency] = scrape_field(page, 'Implementing Agency')
        data[:project_no] = scrape_field(page, 'Project No')
        data[:ward] = scrape_field(page, 'Ward')
        data[:location] = scrape_field(page, 'Location')
        data[:facility] = scrape_field(page, 'Facility Name or Identifier')
        data[:status] = scrape_field(page, 'Status')
        data[:est_cost] = scrape_field(page, 'Estimated Full Funding Cost')
        data[:description] = scrape_paragraph(page, 'Description')
        data[:justification] = scrape_paragraph(page, 'Justification')
        data[:progress_assessment] = scrape_paragraph(page, 'Progress Assessment')
        data[:funding_by_phase] = scrape_funding_table(page, 'Phase', fy)
        data[:funding_by_source] = scrape_funding_table(page, 'Source', fy)
        data[:milestones] = scrape_milestones_table(page)
        data[:related_projects] = scrape_paragraph_with_end_test(page, 'Related Projects') { |cur|
            cur.text.include? '(Dollars in Thousands)'
        }

        if fy == 10 then
            data[:useful_life] = scrape_field_single_el(page, 'Useful Life of the Project')
        else
            data[:useful_life] = scrape_field(page, 'Useful Life of the Project')
        end

        if data[:useful_life] && data[:useful_life] != '' then
            data[:useful_life] = data[:useful_life].to_i
        end

        if data[:est_cost] && data[:est_cost] != '' then
            data[:est_cost] = data[:est_cost].gsub(/\D/,'').to_i
        end

        projects.push(data)
    end
end

File.open(OUTPUT_FILE, 'w') do |fo|
    fo.write(projects.to_json)
end
