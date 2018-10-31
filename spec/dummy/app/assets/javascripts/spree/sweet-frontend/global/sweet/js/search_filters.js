jQuery(document).on('ready', function() {
  // BEGIN GLOBAL SEARCH SCRIPTS ////////////////////
  var toggleAdvancedSearch = function() {
    $('i', '#toggle-advanced-search').toggleClass('rotate')
    $('#advanced-search-form').toggleClass('hidden');
    if($('#advanced-search-form').hasClass('hidden')){
      $('#basic-search-buttons').removeClass('hidden');
    }else{
      $('#basic-search-buttons').addClass('hidden');
    }
  }
  $('#toggle-advanced-search').click(function(){
    toggleAdvancedSearch();
  });

  $('.form-group', '#advanced-search-form').each(function(){
    if($(this).data('open') === true){
      toggleAdvancedSearch();
      return false
    }
  })
  // END GLOBAL SEARCH SCRIPTS //////////////////////

  // BEGIN PRODUCT PAGE SCRIPTS /////////////////////
  $('#view-as-account').change(function(){
    $('#view-as-account-id').val(this.value);
    $('#products-search-form').submit();
  });

  $('#account-show-all').change(function(){
    $('#account-viewing-all').val(this.value);
    $('#account_show_all').val(this.value);
    $('#products-search-form').submit();
  });
  // END PRODUCT PAGE SCRIPTS //////////////////////
});
