$( document ).on('ready', function() {
  // $('#view-as-customer').change(function(){
  //   $('#view-as-form').submit();
  // });
  //
  // $('#customer-show-all').change(function(){
  //   $('#view-as-form').submit();
  // });

  var viewAll = ''
  $('.viewable_by').change(function(e){
    $(e.currentTarget).parents('form').submit();
  });
  $('#all-products-to-customer-list').click(function(event) {
    $('#product-list-buttons p').each(function(){

    });
    if(this.checked) {
      viewAll = true
      if($('#add-products').hasClass('hidden')){
        $('#add-products').removeClass('hidden')
      }
      if(!$('#remove-products').hasClass('hidden')){
        $('#remove-products').addClass('hidden')
      }
        // Iterate each checkbox
        $('.viewable_by:checkbox').each(function() {
          if(this.checked === false){
            this.checked = true;
            // $(this).parents('form').submit();
          }
        });
    }else{
      if($('#remove-products').hasClass('hidden')){
        $('#remove-products').removeClass('hidden')
      }
      if(!$('#add-products').hasClass('hidden')){
        $('#add-products').addClass('hidden')
      }
      viewAll = ''
      $('.viewable_by:checkbox').each(function() {
        if(this.checked === true){
          this.checked = false;
          // $(this).parents('form').submit();
        }
      });
    }
  });
  $('#update-all-viewable').click(function(e){
    e.preventDefault();
    // var viewable_by_all = $('#all-products-to-customer-list').val()
    $.ajax({
      url: "/manage/update_all_viewable_variants.js",
      type: "get",
      data: {
        all_viewable_by: viewAll,
        account_id: $('#account-id').val()
      }
    });
  });

  $('#products-on-this-page').click(function(e){
    e.preventDefault
    $('.viewable_by:checkbox').each(function(){
      $(this).parents('form').submit();
    })
    $('#alert').append("<div class='alert alert-success alert-auto-dissapear'>Viewable list has been updated</div>")
  });
  // window.onbeforeunload = function(e) {
  //   var productQtyFlag = false
  //   if(warnBeforeUnload){
  //     $('.product-qty').filter(function() {
  //       if (this.value != '') {
  //         productQtyFlag = true;
  //         return false;
  //       }
  //     });
  //   }
  //   if(productQtyFlag){
  //     $('#all-products').removeClass('hidden');
  //     $('section.loader').remove();
  //     return "You have products on this page that have not been added to your order.  Stay on page and click 'Add to Cart' if you want to keep them.";
  //   }
  // };
});
