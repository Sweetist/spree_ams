function generatePassword(len){
  var pwd = [], cc = String.fromCharCode, R = Math.random, rnd, i;
  pwd.push(cc(48+(0|R()*10))); // push a number
  pwd.push(cc(65+(0|R()*26))); // push an upper case letter

  for(i=2; i<len; i++){
     rnd = 0|R()*62; // generate upper OR lower OR number

     pwd.push(cc(48+rnd+(rnd>9?7:0)+(rnd>35?6:0)));
  }
  return pwd.sort(function(){ return R() - .5; }).join('');
}

$(document).ready( function () {
  $('#modal_main_body').html($('#modal_landing_body').html());

  if ( $('#select_vendor option:selected').text() == 'Select User...' ) {
    $('#btn_download').css('display', 'none');
  } else {
    $('#btn_download').css('display', 'inline-block');
  }

  $(document).on('click', '#select_vendor-styler > .jq-selectbox__select', function() {
    $('.jq-selectbox__dropdown').css('display', 'block');
  });

  $(document).on('change', '#select_vendor', function() {
    if ( $('#select_vendor option:selected').text() == 'Select User...' ) {
      $('#btn_download').css('display', 'none');
      $('#btn_add2').css('display', 'none');
      $('#username').val('');
      $('#qb_pwd').val('');
    } else {
      $('#btn_download').css('display', 'inline-block');
      $('#btn_add2').css('display', 'inline-block');
      $('#username').val($('#select_vendor option:selected').text());
      $('#qb_pwd').val(generatePassword(24));
    }
  });

  $(document).on('click', '.jq-selectbox__dropdown > ul > li', function() {
    $('.jq-selectbox__dropdown').css('display', 'none');
    $('.selected', '#select_vendor-styler').removeClass('selected sel');
    $(this).addClass('selected sel');
    $(".jq-selectbox__select-text", '#select_vendor-styler').text($(this).text());

    if ( $(this).text() == 'Select User...' ) {
      $('#btn_download').css('display', 'none');
      $('#btn_add2').css('display', 'none');
      $('#username').val('');
      $('#qb_pwd').val('');
    } else {
      $('#btn_download').css('display', 'inline-block');
      $('#btn_add2').css('display', 'inline-block');
      $('#username').val($(this).text());
      $('#qb_pwd').val(generatePassword(24));
    }
  });

  $(document).on('click', '#btn_go_back', function() {
    $('#modal_main_body').html($('#modal_landing_body').html());
  });

  $(document).on('click', '#btn_go_online', function() {
    $('#modal_main_body').html($('#modal_online_body').html());      
  });

  $(document).on('click', '#btn_go_desktop', function() {
    $('#modal_main_body').html($('#modal_desktop_body').html());      
  });

  $(document).on('hidden.bs.modal', '#modal_items', function() {
    $('#modal_main_body').html($('#modal_landing_body').html());
  });

  if ($('#div_noitem').length > 0 && $('#modal_items').length > 0 ) {
    // $('#modal_items').modal();
  }

  $(document).on('click', '#btn_sync', function() {
    // $(this).html('<%= image_tag("syncing.gif", id: "img_sync") %>&nbsp;&nbsp;Syncing...');
  });

  $('.dropdown-toggle').dropdown();
});

