/*jslint browser: true*/
/*jslint nomen: true*/
/*global $, _, d3*/

(function () {
    'use strict';

    var app,
        views = {};

    $(function () {
        var controlView = new views.ControlView('.control-view');
    });

    app = {
        initialize: function (data) {
        },
    };

    window.app = app;

    views.ControlView = function (el) {
        $(el).find('.filters .agency-filter').chosen({
            'width': '280px',
            'allow_single_deselect': true
        });
        $(el).find('.filters .ward-filter').chosen({
            'width': '140px',
            'allow_single_deselect': true
        });
        $(el).find('.search input').change(function (e) {
            var target = $(e.target);
            if (target.val() !== '') {
                target.parent().addClass('text-entered');
            } else {
                target.parent().removeClass('text-entered');
            }
        });
        $(el).find('.search .clear-search').click(function (e) {
            $(e.target).siblings('.search .search-bar').val('').change();
        });
    };

}());