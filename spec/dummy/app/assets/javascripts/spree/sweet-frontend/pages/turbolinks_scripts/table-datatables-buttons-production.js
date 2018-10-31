var TableDatatablesButtons = function () {

    var inventoryReportTable = function (){
      var table = $('#inventory-report');
      var oTable = table.dataTable({
      buttons: [
                { extend: 'excel',
                  text: "<i class='fa fa-file-excel-o'></i> Excel",
                  className: 'btn green margin-left-5',
                },
      ],
      "searching": false,
      responsive: false,
      select: false,
      info: false,
      "paging": false,
      "order": false,
      "dom": "<'row' <'col-md-12'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r><'table-scrolable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>"

      })
    }

    var ajaxTable = function () {
      var table = $('.ajaxDatatable')
      var order = table.data("dt-order")
      if (order) {
        order = order.replace(/'/g, '"')
        order = [JSON.parse("[" + order + "]")]
      } else {
        order = []
      }
      var columns = function(){
        var result=[]
        table.find('th').each(function(){
          result.push({data: $(this).data('source'), name: $(this).data('source')})
        })
        return result
      }
      table.on('init.dt', function () {$("#source-dt-buttons")
           .appendTo("#dt-buttons");} ).dataTable(addSettings({
        processing: true,
        serverSide: true,
        ajax: {
          url: table.data('source'),
          type: "POST",
          data: function(d){
            $.extend(d, $('#search-form').serializeObject())
          }
        },
        buttons: [],
        columns: columns(),
        order: order,
        columnDefs: [
          { visible: false, targets: 'dt-invisible' },
          { orderable: false, targets: 'dt-no-sort'}
        ],
        responsive: false,
        select: false,
        searching: true,
        pagingType: 'full_numbers',
        dom: "<'row' <'#dt-buttons.col-md-12 form-group'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'>r><'table-scrollable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>",
        language: {
            "aria": {
                "sortAscending": ": activate to sort column ascending",
                "sortDescending": ": activate to sort column descending"
            },
            "emptyTable": "No data available in table",
            "info": "Showing _START_ to _END_ of _TOTAL_ entries",
            "infoEmpty": "No entries found",
            "infoFiltered": "(filtered from _MAX_ total entries)",
            "lengthMenu": "_MENU_ entries",
            "search": "Search:",
            "zeroRecords": "No matching records found"
        },
      }))
    }

    var initTable1 = function () {
        var table = $('#production');
        var colToSort = table.data("sortcol");
        var numColToSort = parseInt(colToSort);
        var dirToSort = table.data("sortdir");
        var paging = table.data("paging");

        if (paging == undefined){
          paging = true;
        }

        if (colToSort === undefined){
          numColToSort = 0;
        }

        if (dirToSort === undefined){
          dirToSort = 'asc';
        }

        var oTable = table
          .on('init.dt', function () {$("#source-dt-buttons").appendTo("#dt-buttons");} )
          .dataTable(addSettings({
            // Internationalisation. For more info refer to http://datatables.net/manual/i18n
            "language": {
                "aria": {
                    "sortAscending": ": activate to sort column ascending",
                    "sortDescending": ": activate to sort column descending"
                },
                "emptyTable": "No data available in table",
                "info": "Showing _START_ to _END_ of _TOTAL_ entries",
                "infoEmpty": "No entries found",
                "infoFiltered": "(filtered1 from _MAX_ total entries)",
                "lengthMenu": "_MENU_ entries",
                "search": "Search:",
                "zeroRecords": "No matching records found"
            },
            "searching": false,
            // Or you can use remote translation file
            //"language": {
            //   url: '//cdn.datatables.net/plug-ins/3cfcc339e89/i18n/Portuguese.json'
            //},
            'aoColumnDefs': [
              { visible: false, targets: 'dt-invisible' },
              { orderable: false, targets: ['dt-no-sort', 'no-sort']} // add class 'no-sort' to column headers you don't want sorted on
            ],


            buttons: [
              { extend: 'print',
                  text: "<i class='fa fa-print'></i> Print",
                  className: 'btn green margin-left-5',
                  title: table.data('title'),
                  sortCol: numColToSort,
                  sortDir: dirToSort
                },
                // { extend: 'copy', className: 'btn green btn-outline' },
                { extend: 'pdf',
                  text: "<i class='fa fa-file-pdf-o'></i> PDF",
                  className: 'btn green margin-left-5',
                  title: table.data('title'),
                  sortCol: numColToSort,
                  sortDir: dirToSort
                },
                { extend: 'excel',
                  text: "<i class='fa fa-file-excel-o'></i> Excel",
                  className: 'btn green margin-left-5',
                  title: table.data('title'),
                  sortCol: numColToSort,
                  sortDir: dirToSort
                },
                // { extend: 'csv', className: 'btn purple btn-outline ' },
                // { extend: 'colvis',
                //   className: 'btn green margin-left-5',
                //   text: "<i class='fa fa-cog'></i>",
                //   postfixButtons: [ 'colvisRestore' ]
                // }
                // {
                //   extend: 'collection',
                //   text: 'Flag',
                //   buttons: [ 'colvis','colvisRestore' ],
                //   fade: true
                // }
            ],

            // setup responsive extension: http://datatables.net/extensions/responsive/
            responsive: false,

            //"ordering": false, disable column ordering
            "paging": paging, //disable pagination

            "order": [
                [numColToSort, dirToSort] //column number to sort on by default
            ],

            "lengthMenu": [
                [10, 25, 50, 100],
                [10, 25, 50, 100] // change per page values here
            ],
            // set the initial value
            "pageLength": 25,

            "dom": "<'row' <'col-md-12'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r><'table-scrollable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>", // horizobtal scrollable datatable

            // Uncomment below line("dom" parameter) to fix the dropdown overflow issue in the datatable cells. The default datatable layout
            // setup uses scrollable div(table-scrollable) with overflow:auto to enable vertical scroll(see: assets/global/plugins/datatables/plugins/bootstrap/dataTables.bootstrap.js).
            // So when dropdowns used the scrollable div should be removed.
            // "dom": "<'row' <'col-md-12'T>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r>t<'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>",
        }));

        // console.log("Table state: " + oTable.state())
    }

    var initTable2 = function () {
        var table = $('#product-catalog');
        // var paging = table.data("paging");
        // if (paging == undefined){
        //   paging = true;
        // }

        var oTable = table
          .on('init.dt', function () {$("#source-dt-buttons").appendTo("#dt-buttons");} )
          .dataTable(addSettings({

            // Internationalisation. For more info refer to http://datatables.net/manual/i18n
            "language": {
                "aria": {
                    "sortAscending": ": activate to sort column ascending",
                    "sortDescending": ": activate to sort column descending"
                },
                "emptyTable": "No data available in table",
                "info": "Showing _START_ to _END_ of _TOTAL_ entries",
                "infoEmpty": "No entries found",
                "infoFiltered": "(filtered1 from _MAX_ total entries)",
                "lengthMenu": "_MENU_ entries",
                "search": "Search:",
                "zeroRecords": "No matching records found"
            },

            'aoColumnDefs': [
              { visible: false, targets: 'dt-invisible' },
              { orderable: false, targets: ['dt-no-sort', 'no-sort']} // add class 'no-sort' to column headers you don't want sorted on
            ],

            // Or you can use remote translation file
            //"language": {
            //   url: '//cdn.datatables.net/plug-ins/3cfcc339e89/i18n/Portuguese.json'
            //},

            buttons: [

            ],

            // setup responsive extension: http://datatables.net/extensions/responsive/
            info: false,
            responsive: false,
            select: false,
            "searching": false,
            // "deferRender": true,
            "ordering": false, //disable column ordering
            "paging": false, //disable pagination


            // "lengthMenu": [
            //     [5, 10, 15, 20, -1],
            //     [5, 10, 15, 20, "All"] // change per page values here
            // ],
            // set the initial value
            // "pageLength": 10,

            dom: "<'row' <'#dt-buttons.col-md-12 form-group'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'>r><'table-scrollable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>", // horizobtal scrollable datatable

            // Uncomment below line("dom" parameter) to fix the dropdown overflow issue in the datatable cells. The default datatable layout
            // setup uses scrollable div(table-scrollable) with overflow:auto to enable vertical scroll(see: assets/global/plugins/datatables/plugins/bootstrap/dataTables.bootstrap.js).
            // So when dropdowns used the scrollable div should be removed.
            //"dom": "<'row' <'col-md-12'T>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r>t<'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>",
        }));
    }

    var initTable3 = function () {
      var table = $('.basic-table-no-buttons');
      var colToSort = table.data("sortcol");
      var numColToSort = parseInt(colToSort);
      var dirToSort = table.data("sortdir");
      var paging = table.data("paging");

      if (paging == undefined){
        paging = true;
      }

      if (colToSort === undefined){
        numColToSort = 0;
      }

      if (dirToSort === undefined){
        dirToSort = 'asc';
      }
      var oTable = table
        .on('init.dt', function () {$("#source-dt-buttons").appendTo("#dt-buttons");} )
        .dataTable(addSettings({

          // Internationalisation. For more info refer to http://datatables.net/manual/i18n
          "language": {
              "aria": {
                  "sortAscending": ": activate to sort column ascending",
                  "sortDescending": ": activate to sort column descending"
              },
              "emptyTable": "No data available in table",
              "info": "Showing _START_ to _END_ of _TOTAL_ entries",
              "infoEmpty": "No entries found",
              "infoFiltered": "(filtered1 from _MAX_ total entries)",
              "lengthMenu": "_MENU_ entries",
              "search": "Search:",
              "zeroRecords": "No matching records found"
          },
          "searching": false,
          info: false,
          select: false,
          // Or you can use remote translation file
          //"language": {
          //   url: '//cdn.datatables.net/plug-ins/3cfcc339e89/i18n/Portuguese.json'
          //},

          'aoColumnDefs': [
            { visible: false, targets: 'dt-invisible' },
            { orderable: false, targets: ['dt-no-sort', 'no-sort']} // add class 'no-sort' to column headers you don't want sorted on
          ],

          buttons: [
              // { extend: 'print', className: 'btn dark btn-outline' },
              // { extend: 'copy', className: 'btn green btn-outline' },
              // { extend: 'pdf', className: 'btn red btn-outline' },
              // { extend: 'excel', className: 'btn green btn-outline ' },
              // { extend: 'csv', className: 'btn purple btn-outline ' },
              // { extend: 'colvis', className: 'btn dark btn-outline', text: 'Columns'}
          ],

          // setup responsive extension: http://datatables.net/extensions/responsive/
          responsive: false,

          "ordering": false, // disable column ordering
          //"paging": false, //disable pagination
          "paging": paging,
          "order": [
              [numColToSort, dirToSort] //column number to sort on by default
          ],

          'lengthChange': false, // setting to false turns off selecting number of results per page
          "lengthMenu": [
              [10, 25, 50, 100] // change per page values here
          ],
          // set the initial value
          "pageLength": 25,

          dom: "<'row' <'#dt-buttons.col-md-12 form-group'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'>r><'table-scrollable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>", // horizobtal scrollable datatable

          // Uncomment below line("dom" parameter) to fix the dropdown overflow issue in the datatable cells. The default datatable layout
          // setup uses scrollable div(table-scrollable) with overflow:auto to enable vertical scroll(see: assets/global/plugins/datatables/plugins/bootstrap/dataTables.bootstrap.js).
          // So when dropdowns used the scrollable div should be removed.
          //"dom": "<'row' <'col-md-12'T>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r>t<'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>",
      }));
    }


    var initTable4 = function () {
        var table = $('#products-report');
        var paging = table.data("paging");
        if (paging == undefined){
          paging = true;
        }

        var oTable = table
          .on('init.dt', function () {$("#source-dt-buttons").appendTo("#dt-buttons");} )
          .dataTable({

            // Internationalisation. For more info refer to http://datatables.net/manual/i18n
            "language": {
                "aria": {
                    "sortAscending": ": activate to sort column ascending",
                    "sortDescending": ": activate to sort column descending"
                },
                "emptyTable": "No data available in table",
                "info": "Showing _START_ to _END_ of _TOTAL_ entries",
                "infoEmpty": "No entries found",
                "infoFiltered": "(filtered1 from _MAX_ total entries)",
                "lengthMenu": "_MENU_ entries",
                "search": "Search:",
                "zeroRecords": "No matching records found"
            },
            "searching": false,
            // Or you can use remote translation file
            //"language": {
            //   url: '//cdn.datatables.net/plug-ins/3cfcc339e89/i18n/Portuguese.json'
            //},
            'aoColumnDefs': [
              { visible: false, targets: 'dt-invisible' },
              { orderable: false, targets: ['dt-no-sort', 'no-sort']} // add class 'no-sort' to column headers you don't want sorted on
            ],

            buttons: [
                { extend: 'print', className: 'btn dark btn-outline' },
                // { extend: 'copy', className: 'btn green btn-outline' },
                { extend: 'pdf', className: 'btn red btn-outline' },
                { extend: 'excel', className: 'btn green btn-outline ' },
                // { extend: 'csv', className: 'btn purple btn-outline ' },
                // { extend: 'colvis', className: 'btn dark btn-outline', text: 'Columns'}
            ],

            // setup responsive extension: http://datatables.net/extensions/responsive/
            responsive: false,

            //"ordering": false, disable column ordering
            "paging": paging, //disable pagination

            "order": [
                [0, 'dsc']
            ],

            "lengthMenu": [
                [10, 25, 50, 100],
                [10, 25, 50, 100] // change per page values here
            ],
            // set the initial value
            "pageLength": 25,

            "dom": "<'row' <'col-md-12'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r><'table-scrollable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>", // horizobtal scrollable datatable

            // Uncomment below line("dom" parameter) to fix the dropdown overflow issue in the datatable cells. The default datatable layout
            // setup uses scrollable div(table-scrollable) with overflow:auto to enable vertical scroll(see: assets/global/plugins/datatables/plugins/bootstrap/dataTables.bootstrap.js).
            // So when dropdowns used the scrollable div should be removed.
            //"dom": "<'row' <'col-md-12'T>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r>t<'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>",
        });
    }

    var initTable5 = function () {
        var table = $('#short-table-no-buttons');
        var paging = table.data("paging");
        if (paging == undefined){
          paging = true;
        }

        var oTable = table
          .on('init.dt', function () {$("#source-dt-buttons").appendTo("#dt-buttons");} )
          .dataTable(addSettings({

            // Internationalisation. For more info refer to http://datatables.net/manual/i18n
            "language": {
                "aria": {
                    "sortAscending": ": activate to sort column ascending",
                    "sortDescending": ": activate to sort column descending"
                },
                "emptyTable": "No data available in table",
                "info": "Showing _START_ to _END_ of _TOTAL_ entries",
                "infoEmpty": "No entries found",
                "infoFiltered": "(filtered1 from _MAX_ total entries)",
                "lengthMenu": "_MENU_ entries",
                "search": "Search:",
                "zeroRecords": "No matching records found"
            },
            "searching": false,
            // Or you can use remote translation file
            //"language": {
            //   url: '//cdn.datatables.net/plug-ins/3cfcc339e89/i18n/Portuguese.json'
            //},
            'aoColumnDefs': [
              { visible: false, targets: 'dt-invisible' },
              { orderable: false, targets: ['dt-no-sort', 'no-sort']} // add class 'no-sort' to column headers you don't want sorted on
            ],

            buttons: [
                // { extend: 'print', className: 'btn dark btn-outline' },
                // { extend: 'copy', className: 'btn green btn-outline' },
                // { extend: 'pdf', className: 'btn red btn-outline' },
                // { extend: 'excel', className: 'btn green btn-outline ' },
                // { extend: 'csv', className: 'btn purple btn-outline ' },
                // { extend: 'colvis', className: 'btn dark btn-outline', text: 'Columns'}
            ],

            // setup responsive extension: http://datatables.net/extensions/responsive/
            responsive: false,

            //"ordering": false, disable column ordering
            "paging": paging, //disable pagination

            "order": [
                [1, 'dsc']
            ],

            'lengthChange': false, // setting to false turns off selecting number of results per page
            "lengthMenu": [
                [10, 25, 50, 100] // change per page values here
            ],
            // set the initial value
            "pageLength": 25,

            "dom": "<'row' <'col-md-12'B>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r><'table-scrollable't><'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>", // horizobtal scrollable datatable

            // Uncomment below line("dom" parameter) to fix the dropdown overflow issue in the datatable cells. The default datatable layout
            // setup uses scrollable div(table-scrollable) with overflow:auto to enable vertical scroll(see: assets/global/plugins/datatables/plugins/bootstrap/dataTables.bootstrap.js).
            // So when dropdowns used the scrollable div should be removed.
            //"dom": "<'row' <'col-md-12'T>><'row'<'col-md-6 col-sm-12'l><'col-md-6 col-sm-12'f>r>t<'row'<'col-md-5 col-sm-12'i><'col-md-7 col-sm-12'p>>",
        }));
    }

    // var initAjaxDatatables = function () {
    //
    //     //init date pickers
    //     $('.date-picker').datepicker({
    //         rtl: App.isRTL(),
    //         autoclose: true
    //     });
    //
    //     var grid = new Datatable();
    //
    //     grid.init({
    //         src: $("#datatable_ajax"),
    //         onSuccess: function (grid, response) {
    //             // grid:        grid object
    //             // response:    json object of server side ajax response
    //             // execute some code after table records loaded
    //         },
    //         onError: function (grid) {
    //             // execute some code on network or other general error
    //         },
    //         onDataLoad: function(grid) {
    //             // execute some code on ajax data load
    //         },
    //         loadingMessage: 'Loading...',
    //         dataTable: { // here you can define a typical datatable settings from http://datatables.net/usage/options
    //
    //             // Uncomment below line("dom" parameter) to fix the dropdown overflow issue in the datatable cells. The default datatable layout
    //             // setup uses scrollable div(table-scrollable) with overflow:auto to enable vertical scroll(see: assets/global/scripts/datatable.js).
    //             // So when dropdowns used the scrollable div should be removed.
    //
    //             //"dom": "<'row'<'col-md-8 col-sm-12'pli><'col-md-4 col-sm-12'<'table-group-actions pull-right'>>r>t<'row'<'col-md-8 col-sm-12'pli><'col-md-4 col-sm-12'>>",
    //
    //             "bStateSave": true, // save datatable state(pagination, sort, etc) in cookie.
    //
    //             "lengthMenu": [
    //                 [10, 20, 50, 100, 150, -1],
    //                 [10, 20, 50, 100, 150, "All"] // change per page values here
    //             ],
    //             "pageLength": 10, // default record count per page
    //             "ajax": {
    //                 "url": "../demo/table_ajax.php", // ajax source
    //             },
    //             "order": [
    //                 [1, "asc"]
    //             ],// set first column as a default sort by asc
    //
    //             // Or you can use remote translation file
    //             //"language": {
    //             //   url: '//cdn.datatables.net/plug-ins/3cfcc339e89/i18n/Portuguese.json'
    //             //},
    //
    //             buttons: [
    //                 { extend: 'print', className: 'btn default' },
    //                 { extend: 'copy', className: 'btn default' },
    //                 { extend: 'pdf', className: 'btn default' },
    //                 { extend: 'excel', className: 'btn default' },
    //                 { extend: 'csv', className: 'btn default' },
    //                 {
    //                     text: 'Reload',
    //                     className: 'btn default',
    //                     action: function ( e, dt, node, config ) {
    //                         dt.ajax.reload();
    //                         alert('Datatable reloaded!');
    //                     }
    //                 }
    //             ],
    //
    //         }
    //     });
    //
    //     // handle group actionsubmit button click
    //     grid.getTableWrapper().on('click', '.table-group-action-submit', function (e) {
    //         e.preventDefault();
    //         var action = $(".table-group-action-input", grid.getTableWrapper());
    //         if (action.val() != "" && grid.getSelectedRowsCount() > 0) {
    //             grid.setAjaxParam("customActionType", "group_action");
    //             grid.setAjaxParam("customActionName", action.val());
    //             grid.setAjaxParam("id", grid.getSelectedRows());
    //             grid.getDataTable().ajax.reload();
    //             grid.clearAjaxParams();
    //         } else if (action.val() == "") {
    //             App.alert({
    //                 type: 'danger',
    //                 icon: 'warning',
    //                 message: 'Please select an action',
    //                 container: grid.getTableWrapper(),
    //                 place: 'prepend'
    //             });
    //         } else if (grid.getSelectedRowsCount() === 0) {
    //             App.alert({
    //                 type: 'danger',
    //                 icon: 'warning',
    //                 message: 'No record selected',
    //                 container: grid.getTableWrapper(),
    //                 place: 'prepend'
    //             });
    //         }
    //     });
    //
    //     //grid.setAjaxParam("customActionType", "group_action");
    //     //grid.getDataTable().ajax.reload();
    //     //grid.clearAjaxParams();
    //
    //     // handle datatable custom tools
    //     $('#datatable_ajax_tools > li > a.tool-action').on('click', function() {
    //         var action = $(this).attr('data-action');
    //         grid.getDataTable().button(action).trigger();
    //     });
    // }

    return {

        //main function to initiate the module
        init: function () {

            if (!jQuery().dataTable) {
                return;
            }

            initTable1();
            initTable2();
            initTable3();
            initTable4();
            initTable5();
            ajaxTable()
            inventoryReportTable()
            // initAjaxDatatables();
        }

    };

}();

jQuery(document).on('ready', function() {
  TableDatatablesButtons.init();
});
