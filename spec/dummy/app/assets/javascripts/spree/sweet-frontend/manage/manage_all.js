//= require spree/sweet-frontend/manage/js/overview_datepicker
//= require spree/sweet-frontend/manage/js/product_list
//= require spree/sweet-frontend/manage/js/bundles_and_assemblies
//= require ckeditor/init

var addPartToAssembly = function(variantId, partId, qtyToAdd, nextIdx, variantIdx){
  $.ajax({
     url: '/manage/variants/'+ variantId +'/add_part_to_assembly.js' ,
    type: 'POST',
    dataType: 'script',
    data: {
      part_id: partId,
      qty_to_add: qtyToAdd,
      idx: nextIdx,
      variant_idx: variantIdx
    }
  });
}

var loadBuildAssemblyForm = function(variantId){
  $.ajax({
     url: '/manage/variants/'+ variantId +'/load_parts_variants.js' ,
    type: 'GET',
    dataType: 'script',
  });
}

var loadOptionType = function(optionTypeId, variantId){
  $.ajax({
    url: '/manage/option_types/'+ optionTypeId +'/edit.js',
    type: 'GET',
    dataType: 'script',
    data: { variant_id: variantId}
  });
}

var newOptionType = function(position){
  $.ajax({
    url: '/manage/option_types/new.js',
    type: 'GET',
    dataType: 'script',
    data: {ot_position: position}
  });
}

var initLoadAssemblyForm = function(){
  $('.btn-build-assembly').click(function(){
    $('#product-name','#build-assembly-modal').empty();
    $('#modal-form-container','#build-assembly-modal').empty();
    $('#loading-message','#build-assembly-modal').show();
    loadBuildAssemblyForm($(this).data('variant-id'));
  });
}

var initVariantModal = function(){
  $('.variant-modal-btn').off('click').click(function(e){
    e.preventDefault();
    var action = $(this).data('action');
    var variantId = $(this).data('variant-id');
    var productId = $(this).data('product-id');
    var accountId = $(this).data('account-id');
    var variantUrl

    if (action == 'edit'){
      variantUrl = '/manage/products/'+ productId +'/variants/' + variantId + '/edit.js';
    }else if (action == 'new'){
      variantUrl = '/manage/products/'+ productId +'/variants/new.js';
    }else{
      variantUrl = '/manage/products/'+ productId +'/variants/' + variantId + '.js';
    }

    $.ajax({
      url: variantUrl,
      type: 'GET',
      data:{
        account_id: accountId
      }
    });
  });
}

var initProductModal = function(){
  $('.product-modal-btn').click(function(e){
    e.preventDefault();
    var action = $(this).data('action');
    var productId = $(this).data('product-id');
    var accountId = $(this).data('account-id');
    var productUrl

    if (action == 'edit'){
      productUrl = '/manage/products/'+ productId +'/edit.js';
    }else if (action == 'new'){
      productUrl = '/manage/products/'+ productId +'/new.js';
    }else{
      productUrl = '/manage/products/'+ productId +'.js';
    }

    $.ajax({
      url: productUrl,
      type: 'GET',
      data:{
        account_id: accountId
      }
    });
  });
}

var newOptionTypeModal = function(position){
  $('#option-type-modal').modal('show');
  newOptionType(position);
}

var handleOptionTypeChange = function(ot0, ot1, ot2, ot3, optionType){
  var optionTypeId = $(optionType).find(':selected').val();
  var position = $(optionType).data('ot-position');
  if (optionTypeId === 'new'){
    newOptionTypeModal(position);
  }
  var otChanged = false
  var currentOt0 = $('#product_product_option_types_attributes_0_option_type_id').val();
  var currentOt1 = $('#product_product_option_types_attributes_1_option_type_id').val();
  var currentOt2 = $('#product_product_option_types_attributes_2_option_type_id').val();
  var currentOt3 = $('#product_product_option_types_attributes_3_option_type_id').val();
  if (currentOt0 !== ot0) { otChanged = true }
  if (currentOt1 !== ot1) { otChanged = true }
  if (currentOt2 !== ot2) { otChanged = true }
  if (currentOt3 !== ot3) { otChanged = true }

  if (otChanged){
    $('#new-variant-btn').attr('disabled', 'disabled');
    $('#save-before-variants-message').removeClass('hidden');
  }else{
    $('#new-variant-btn').removeAttr('disabled');
    $('#save-before-variants-message').addClass('hidden');
  }
}

var compileSortAttributes = function(base){

  var primaryColumnId = '#' + base + '_primary_sort_column'
  var primaryDirId = '#' + base + '_primary_sort_direction'
  var secondaryColumnId = '#' + base + '_secondary_sort_column'
  var secondaryDirId = '#' + base + '_secondary_sort_direction'

  var sortString = ''

  if( $(primaryColumnId).length && ($(primaryColumnId).val() != '') ){
    sortString = sortString.concat($(primaryColumnId).val(), ' ', $(primaryDirId).val());
  }
  if($(secondaryColumnId).length && ($(secondaryColumnId).val() != '')){
    sortString = sortString.concat(' ', $(secondaryColumnId).val(), ' ', $(secondaryDirId).val());
  }

  $("#" + base + "_default_sort").val(sortString.trim());
}

$(document).ready(function(){
  initLoadAssemblyForm();
  initVariantModal();
  initProductModal();
});
