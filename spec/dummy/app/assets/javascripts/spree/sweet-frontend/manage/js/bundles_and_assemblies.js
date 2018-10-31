var sumPartCost = function(){
  var sum = 0;
  $('.part-total-cost').each(function(){
    var partTotalCost = parseFloat($(this).text());
    if(partTotalCost !== undefined){
      sum = sum + partTotalCost;
    }
  });
  $('#variant_sum_cost_price').val(sum.toFixed(2));
  $('#sum_parts_cost').text(sum.toFixed(2));
}

var updatePartTotalCost = function($partRow){
  var qty = $partRow.find('.count').val();
  var unitCost = parseFloat($partRow.find('.part-unit-cost').text());
  if(qty !== NaN && unitCost !== NaN){
    $partRow.find('.part-total-cost').text(String((qty * unitCost).toFixed(2)))
  }
}
var updatePartTotalWeight = function($partRow){
  var qty = $partRow.find('.count').val();
  var unitWeight = parseFloat($partRow.find('.part-unit-weight').text());
  if(qty !== NaN && unitWeight !== NaN){
    $partRow.find('.part-total-weight').text(String(qty * unitWeight))
  }
}

var initAssembly = function() {
  // $('.count').off('change').change(function() {
  //   var sub_product_id = this.id;
  //   sub_product_ids[parseInt(sub_product_id)] = this.value;
  // });

  $('.update_part_id').off('click').click(function(e){
    e.preventDefault();
    var variantId = $(this).data('variant-id');
    var partId = $('#sub_product_id_' + variantId + ' option:selected').val();
    var qtyToAdd = $('#qty_to_add_' + variantId).val();
    var variantIdx = $('#qty_to_add_' + variantId).data('form-index');
    if (partId !== '' && partId != undefined) {
      var $partVariantRow = $('#variant_' + variantId + '_part_' + partId + '_row');
      if ($partVariantRow.length){
        $partVariantRow.show();
        $partVariantRow.find('.count').val(qtyToAdd);
        $partVariantRow.find('.hidden_destroy').val(false);
      }else{
        var $last_row = $('#sub-parts-table-body-'+ variantId).find('tr.part-row').last()
        var nextIdx = 0
        if ($last_row.length){
          nextIdx = parseInt($last_row.data('index')) + 1;
        }
        addPartToAssembly(variantId, partId, qtyToAdd, nextIdx, variantIdx);
      }
    } else {
      alert("Nothing Selected");
    }
  });

  $(document).on('click', '.delete_part_id', function(e){
    e.preventDefault();
    variantId = $(this).data('variant-id');
    partId = $(this).data('part-id');
    partVariantId = $(this).data('part-variant-id');
    $partVariantRow = $('#variant_' + variantId + '_part_' + partId + '_row')
    if (partVariantId === ''){
      $partVariantRow.remove();
    }else{
      $partVariantRow.find('.hidden_destroy').val(true);
      $partVariantRow.hide();
    }
    updatePartTotalCost($(this.closest('tr')));
    updatePartTotalWeight($(this.closest('tr')));
    sumPartCost();
  });
}
