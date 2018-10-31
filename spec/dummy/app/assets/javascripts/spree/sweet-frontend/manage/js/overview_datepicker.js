$(function(){
  var overviewDate = $('#overview-date');
  var form = $("#datepicker-form");
  var holder_links = $('#overview-date-holder a');

  overviewDate.datepicker({
    rtl: App.isRTL(),
    orientation: "left",
    autoclose: true
  });

  overviewDate.change(function(e){
    form.submit();
  });

  function changeDate(target, date){
    overviewDate.val(date.format(overviewDate.data('date-format').toUpperCase()));
    overviewDate.change();
  };

  holder_links.click(function(e){
    var date = moment($(e.currentTarget).attr('data-overview-date'));
    changeDate(overviewDate, date);
  });


  $('body').keyup(function(e){
    switch(e.keyCode) {
    case 39:
      var date = moment(overviewDate.val());
      date.add(1, 'day');
      changeDate(overviewDate, date);
      break;
    case 37:
      var date = moment(overviewDate.val());
      date.subtract(1, 'day');
      changeDate(overviewDate, date);
      break;
    };
  });



});