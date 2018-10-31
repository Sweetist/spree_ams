$.fn.companyAutocomplete = function (options) {
  'use strict';
  // Default options
  options = options || {};
  var multiple = false;

  this.select2({
    minimumInputLength: 1,
    multiple: multiple,
    initSelection: function (element, callback) {
      $.get(Spree.routes.company_search, {
        ids: element.val().split(','),
        token: Spree.api_key
      }, function (data) {
        callback(multiple ? data.companies : data.companies[0]);
      });
    },
    ajax: {
      url: Spree.routes.company_search,
      datatype: 'json',
      data: function (term, page) {
        return {
          q: {
            name_cont: term
          },
          token: Spree.api_key
        };
      },
      results: function (data, page) {
        var companies = data.companies ? data.companies : [];
        return {
          results: companies
        };
      }
    },
    formatResult: function (company) {
      return company.name + ' (id=' + company.id + ')';
    },
    formatSelection: function (company) {
      return company.name  + ' (id=' + company.id + ')';
    }
  });
};

$(document).ready(function () {
  $('.company_id').companyAutocomplete();
});
