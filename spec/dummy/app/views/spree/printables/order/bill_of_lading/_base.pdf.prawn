@font_style = {
  face: @doc.printable.vendor.font_face,
  size: @doc.printable.vendor.font_size.to_i
}
vendor = @doc.printable.vendor
prawn_document do |pdf|
  pdf.define_grid(columns: 5, rows: 8, gutter: 10)
  pdf.font @font_style[:face], size: @font_style[:size]

  pdf.repeat(:all) do
    render 'spree/printables/order/bill_of_lading/header', pdf: pdf, printable: @doc
  end

  # CONTENT
  line_item_grid_end = 5
  line_item_grid_end += 1 unless vendor.bol_terms_and_condtions1.present? || vendor.bol_terms_and_condtions2.present?
  pdf.grid([1,0], [line_item_grid_end,4]).bounding_box do

    # address block on first page only
    if pdf.page_number == 1

      ship_via_content = "#{Spree.t(:shipping_method, scope: :print_invoice)}: <b>#{@doc.printable.shipping_method.try(:name)}</font>"
      date_content = Spree.t("#{@doc.document_type}_date", scope: :print_invoice, date_type: vendor.order_date_text.to_s.capitalize, date: "<b>#{@doc.printable.display_date}</font>")
      ship_via_label = pdf.make_cell(content: ship_via_content, inline_format: true)
      date_label = pdf.make_cell(content: date_content, inline_format: true)

      data = [[ship_via_label, date_label]]

      pdf.table(data, header: false, position: :center,
        column_widths: [pdf.bounds.width / 2, pdf.bounds.width / 2],
        cell_style: { border_width: 0, borders: []})
      #   do
      #   # column(0..1).style align: :right
      #   # column(1).style font_style: :bold
      #   # column(3).style font_style: :bold
      # end
      pdf.move_down 2
      render 'spree/printables/order/bill_of_lading/address_block', pdf: pdf, printable: @doc

    end

    pdf.move_down 10

    render 'spree/printables/order/bill_of_lading/items', pdf: pdf, printable: @doc


  end

  # Footer
    render 'spree/printables/order/bill_of_lading/footer', pdf: pdf, footer_row_start: line_item_grid_end + 1

  # Page Number
  if @doc.printable.vendor.use_page_numbers
    render 'spree/printables/shared/page_number', pdf: pdf
  end
end
