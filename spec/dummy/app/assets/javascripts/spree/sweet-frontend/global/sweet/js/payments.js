var toggleCardForm = function(paymentMethodId){
  pmId = paymentMethodId.toString();
  var useNewCardId = '#card_new' + pmId;
  var useNewCard = '#card_new' + pmId + ':checked';
  var cardForm = '#card_form' + pmId;
  var usesProfiles = $(cardForm).data('profiles');
  if($(useNewCard).length || !usesProfiles){
    $(cardForm).show();
  }else{
    $(cardForm).hide();
  }
}

var togglePaymentMethodViews = function(){
  var selectedMethod = $('#payment_payment_method_id').val();
  $('.payment-methods').each(function(){
    if($(this).data('method') == selectedMethod){
      $(this).show();
      if($(this).data('creditcard')){
        $('#non-credit-card-params').hide();
        toggleCardForm(selectedMethod);
        $('#use-for-mark-paid-container').hide();
        $('input#mark_paid').prop('checked', false);
      }else{
        $('#non-credit-card-params').show();
        if($('#use-for-mark-paid-container').hasClass('mark-paid-visible')){
          $('#use-for-mark-paid-container').show();
        }else{
          $('#use-for-mark-paid-container').hide();
        }
      }
    }else{
      $(this).hide();
    }

  });
}
