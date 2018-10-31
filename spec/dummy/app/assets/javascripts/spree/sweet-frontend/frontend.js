// BEGIN CORE PLUGINS
//= require spree/sweet-frontend/global/plugins/jquery.min
//= require jquery_ujs
// require turbolinks
// require spree/sweet-frontend/turbolinks.5.0.0.beta4
//= require spree/sweet-frontend/global/plugins/bootstrap/js/bootstrap.min
//= require spree/sweet-frontend/global/plugins/js.cookie.min
//= require spree/sweet-frontend/global/plugins/bootstrap-hover-dropdown/bootstrap-hover-dropdown.min
//= require spree/sweet-frontend/global/plugins/jquery-slimscroll/jquery.slimscroll.min
//= require spree/sweet-frontend/global/plugins/jquery.blockui.min
//= require spree/sweet-frontend/global/plugins/uniform/jquery.uniform.min
//= require spree/sweet-frontend/global/plugins/bootstrap-switch/js/bootstrap-switch.min
//= require commontator/application

// BEGIN PAGE LEVEL PLUGINS
//= require cocoon
//= require spree/sweet-frontend/global/plugins/moment.min
//= require spree/sweet-frontend/global/plugins/bootstrap-daterangepicker/daterangepicker.min
//= require spree/sweet-frontend/global/plugins/bootstrap-datepicker/js/bootstrap-datepicker.js
//= require spree/sweet-frontend/global/plugins/bootstrap-timepicker/js/bootstrap-timepicker.min
//= require spree/sweet-frontend/global/plugins/bootstrap-datetimepicker/js/bootstrap-datetimepicker.min
//= require spree/sweet-frontend/global/plugins/datatables/datatables
//= require spree/sweet-frontend/global/plugins/datatables/plugins/bootstrap/datatables.bootstrap
//= require spree/sweet-frontend/global/plugins/datatables/plugins/bootstrap/buttons.bootstrap
//= require spree/sweet-frontend/global/plugins/jquery-minicolors/jquery.minicolors.min
//= require spree/sweet-frontend/global/plugins/select2/js/select2.full.min
//= require spree/sweet-frontend/global/plugins/typeahead/handlebars.min
//= require spree/sweet-frontend/global/plugins/typeahead/typeahead.bundle.min
//= require jquery-ui/sortable
//= require jquery-ui/effect
//= require highcharts
//= require highcharts/highcharts-more
//= require spree/sweet-frontend/global/plugins/jquery.deserialize.min
//= require spree/sweet-frontend/global/plugins/jquery.serializeObject
//= require spree/sweet-frontend/global/plugins/clipboard/clipboard.min

// BEGIN THEME GLOBAL SCRIPTS
//= require spree/sweet-frontend/global/scripts/app

// BEGIN THEME LAYOUT SCRIPTS
//= require spree/sweet-frontend/layouts/layout/scripts/layout.min

// BEGIN PAGE LEVEL SCRIPTS
//= require spree/sweet-frontend/pages/turbolinks_scripts/table-datatables-buttons-production
//= require spree/sweet-frontend/pages/scripts/datatable_settings
//= require spree/sweet-frontend/pages/turbolinks_scripts/components-select2
//= require spree/sweet-frontend/pages/turbolinks_scripts/components-date-time-pickers
//= require spree/sweet-frontend/pages/scripts/validator
//= require spree/sweet-frontend/global/sweet/js/search_filters
//= require spree/sweet-frontend/global/sweet/js/payments

// require spree/sweet-frontend/pages/components-select2
// require spree/sweet-frontend/pages/components-date-time-pickers

var warnBeforeUnload = true;
var preventSecondSubmit = function($form, e) {
  if ($form.data('submitted') === true) {
    // Previously submitted - don't submit again
    e.preventDefault();
  } else {
    $form.data('submitted', true);
    $('body').addClass('wait');
    $('input[type=submit]', '.prevent-double-submission').addClass('disabled');
    $('button', '.prevent-double-submission').addClass('disabled');
    $('a', '.prevent-double-submission').addClass('disabled');
    $('button', '.prevent-double-submission').prop('disabled', 'disabled');
    $('a', '.prevent-double-submission').prop('disabled', 'disabled');
    $form.find('input[type=submit]').addClass('disabled');
    $form.find('button').addClass('disabled');
    $form.find('a').addClass('disabled');
    $form.find('button').prop('disabled', 'disabled');
    $form.find('a').prop('disabled', 'disabled');
  }
}

var disableFormInputs = function($form){
  $form.find('input').each(function(){
    $(this).addClass('disabled');
    $(this).prop('disabled', 'disabled');
  });
  $form.find('select').each(function(){
    $(this).addClass('disabled');
    $(this).prop('disabled', 'disabled');
  });
  $form.find('textarea').each(function(){
    $(this).addClass('disabled');
    $(this).prop('disabled', 'disabled');
  });
  $form.find('.make-switch').each(function(){
    $(this).bootstrapSwitch('disabled',true);
  });
}
var viewOnlyForm = function($form){
  $form.find('input').keypress(function(e){
    e.preventDefault();
  });
  $form.find('input[type="submit"]').click(function(e){
    e.preventDefault()
  });
  $form.find('button').click(function(e){
    e.preventDefault();
  });
  $form.find('a').click(function(e){
    e.preventDefault();
  })
}
var initPreventDoubleSubmission = function () {
  $('form.prevent-double-submission').off('submit').submit( function (e) {
    var $form = $(this);
    preventSecondSubmit($form, e);
  });
  $('.disable-after-click').off('click').click(function(e){
    $('body').addClass('wait');
    $('.disable-after-click').addClass('disabled');
  });
};
var reEnableForm = function () {
  var $form = $('form.prevent-double-submission');
  $form.data('submitted', false);
  $('body').removeClass('wait');
  $('input[type=submit]', '.prevent-double-submission').removeClass('disabled');
  $('button', '.prevent-double-submission').removeClass('disabled');
  $('a', '.prevent-double-submission').removeClass('disabled');
  $('input[type=submit]', '.prevent-double-submission').removeAttr('disabled');
  $('button', '.prevent-double-submission').removeAttr('disabled');
  $('a', '.prevent-double-submission').removeAttr('disabled');
  $form.find('input[type=submit]').removeClass('disabled');
  $form.find('button').removeClass('disabled');
  $form.find('a').removeClass('disabled');
  $form.find('input[type=submit]').removeAttr('disabled');
  $form.find('button').removeAttr('disabled');
  $form.find('a').removeAttr('disabled');
}
var enableFormButtons = function () {
  $('input[type=submit]', '.prevent-double-submission').removeClass('disabled');
  $('button', '.prevent-double-submission').removeClass('disabled');
  $('a', '.prevent-double-submission').removeClass('disabled');
  $('input[type=submit]', '.prevent-double-submission').removeAttr('disabled');
  $('button', '.prevent-double-submission').removeAttr('disabled');
  $('a', '.prevent-double-submission').removeAttr('disabled');
}
var initNumbersOnly = function () {
  $("input[type=number]").off('keypress').keypress(function(e){
     if(
        ( e.which != 46 || $(this).val().indexOf('.') != -1 )
          && ( e.which <  48 || e.which > 57 )
          && ( e.which != 45 )
          && ( e.which != 13 )
       )
     {
         e.preventDefault();
     }
  });
  $("input.number-only").off('keypress').keypress(function(e){
     if(
        ( e.which != 46 || $(this).val().indexOf('.') != -1 )
          && ( e.which <  48 || e.which > 57 )
          && ( e.which != 45 )
          && ( e.which != 13 )
       )
     {
         e.preventDefault();
     }
  });
  $('input[type=number]').on('mousewheel',function(e){ $(this).blur(); });

};

var enableDateReset = function(){
  $('.date-reset').click(function(e){
    e.preventDefault();
    var $datepicker = $(this).parent().find('.date-picker')
    if ($datepicker.length){
      $datepicker.each(function(){
        $(this).data('datepicker').setDate(null);
      });
    }
  });
}

var resizeTextArea = function(){
  $('.autoresize').each(function(){
    var offset = this.offsetHeight - this.clientHeight;
    $(this).css('height', 'auto').css('height', this.scrollHeight + offset);
  });
  $('.autoresize').keyup(function(){
    var offset = this.offsetHeight - this.clientHeight;
    $(this).css('height', 'auto').css('height', this.scrollHeight + offset);
  });
};

$(document).ajaxStart(function () {
  $('body').addClass('wait');
}).ajaxComplete(function () {
  $('body').removeClass('wait');
  $('.disable-after-click').removeClass('disabled')
  $('.modal-hide', '.modal').hide();
  initNumbersOnly();
  initPreventDoubleSubmission();
});
// var ready = function() {
$(document).ready(function(){
  var clipboard = new ClipboardJS('.copy-btn');

  clipboard.on('success', function(e){
    var $trigger = $(e.trigger);
    $($trigger.data('clipboard-target')).blur();
    $trigger.tooltip('show');
    $trigger.mouseover(function(){
      $(this).tooltip('destroy');
    });
    setTimeout(function() {
      $trigger.tooltip('destroy');
    },2000);
  });
  App.init(); // init metronic core componets
  Layout.init(); // init layout
  //  TableDatatablesManaged.init();
  //  Index.init();
  //  Index.initDashboardDaterange();
  //  Index.initJQVMAP(); // init index page's custom scripts
  //  Index.initCalendar(); // init index page's custom scripts
  //  Index.initCharts(); // init index page's custom scripts
  //  Index.initChat();
  //  Index.initMiniCharts();
  //  Index.initIntro();
  //  Tasks.initDashboardWidget();
  initPreventDoubleSubmission();
  initNumbersOnly();
  enableDateReset();

  $('.minicolors').minicolors({control: 'hue', position: 'bottom-left', theme: 'bootstrap'});

  $.uniform.restore(".comment_share_level");
  $.uniform.restore(".noUniform");

  $('#add-to-order-form').submit(function(){
    warnBeforeUnload = false;
    $('#add-to-cart').attr("disabled","disabled");
    $('#add-to-cart2').attr("disabled","disabled");
  });

  $('#expand-order-details').click(function(){
    $('#minimum-order-details').addClass('hidden');
    $('#order-details-expanded').removeClass('hidden');
  });

  $('#minimize-order-details').click(function(){
    $('#order-details-expanded').addClass('hidden');
    $('#minimum-order-details').removeClass('hidden');
  });

  setTimeout(function() {
    $(".alert-auto-dissapear").fadeOut(1500);
  },2000);

  $(".observe_field").on('change', function() {
    target = $(this).data("update");
    $(target).hide();
    $.ajax({ dataType: 'html',
             url: $(this).data("base-url")+encodeURIComponent($(this).val()),
             type: 'get',
             success: function(data){
               $(target).html(data);
               $(target).show();
             }
    });
  });

  var uniqueId = 1;

  // Fix sortable helper
  var fixHelper = function(e, ui) {
      ui.children().each(function() {
          $(this).width($(this).width());
      });
      return ui;
  };

  $('table.sortable').ready(function(){
    var td_count = $(this).find('tbody tr:first-child td').length;
    $('table.sortable tbody').sortable(
      {
        handle: '.handle',
        helper: fixHelper,
        placeholder: 'ui-sortable-placeholder',
        update: function(event, ui) {
          $("#progress").show();
          positions = {};
          $.each($('table.sortable tbody tr'), function(position, obj){
            reg = /spree_(\w+_?)+_(\d+)/;
            parts = reg.exec($(obj).prop('id'));
            if (parts) {
              positions['positions['+parts[2]+']'] = position;
            }
          });
          $.ajax({
            type: 'POST',
            dataType: 'script',
            url: $(ui.item).closest("table.sortable").data("sortable-link"),
            data: positions,
            success: function(data){ $("#progress").hide(); }
          });
        },
        start: function (event, ui) {
          // Set correct height for placeholder (from dragged tr)
          ui.placeholder.height(ui.item.height());
          // Fix placeholder content to make it correct width
          ui.placeholder.html("<td colspan='"+(td_count-1)+"'></td><td class='actions'></td>");
        },
        stop: function (event, ui) {
          // Fix odd/even classes after reorder
          $("table.sortable tr:even").removeClass("odd even").addClass("even");
          $("table.sortable tr:odd").removeClass("odd even").addClass("odd");
        }

      });
  });

  $('a.dismiss').click(function() {
    $(this).parent().fadeOut();
  });

  /** DROPDOWN SELECT **/
  $('.tab-link').click(function(){

    $('.tab-link').removeClass("active");
    var str = $(this).text();
    var strEdited = str.trim();
    /* changing the text on the button */
    $("button.dropdown-btn-text").find("label").replaceWith("<label>" +str+ "</label>");

    /*making the long-tbas active simultaneously*/
    $('.long-tabs-link').each(function(){
      if($(this).text().trim() === strEdited){
        $(this).addClass("active");
      }else{
        $(this).removeClass("active");
      }
    });
  });

  /** CHANGING THE TEXT ON BUTTON **/
   $('.long-tabs-link').click(function(){
     var str = $(this).text();
     $("button.dropdown-btn-text").find("label").replaceWith("<label>" +str+ "</label>");
   });


  $(".chart-block .tabs label").click(function(e){
    e.preventDefault();
    if(!$(this).hasClass('active')){
      if($(this).hasClass('pie-chart')){
        $('.chart-block .chart div#pie-chart div').addClass('active');
        $('.chart-block .chart div#bar-chart div').removeClass('active');
      } else if($(this).hasClass('bar-chart')){
        $('.chart-block .chart div#pie-chart div').removeClass('active');
        $('.chart-block .chart div#bar-chart div').addClass('active');
      }
    }
  });

  // MAKING BOOTSTRAP TABS PERSISTENT
  // http://stackoverflow.com/questions/9685968/best-way-to-make-twitter-bootstrap-tabs-persistent
  // show active tab on reload
  if (location.hash !== '') {
    $('a[href="' + location.hash + '"]').tab('show');
  }

  $("a[data-toggle='tab']").on("shown.bs.tab", function (e) {
    var hash = $(e.target).attr("href");
    if (hash.substr(0,1) == "#") {
      var position = $(window).scrollTop();
      location.replace("#" + hash.substr(1));
      $(window).scrollTop(position);
    }
  });

  $('.image-size-check').bind('change', function() {
    //this.files[0].size gets the size of your file.
    if ( this.files[0].size/1024/1024 > 4 ) {
      alert('This file is too large. Maximum file size is 4 Mb');
      this.value = '';
    }
  });

});
// };

// $(document).on('turbolinks:load', ready);
