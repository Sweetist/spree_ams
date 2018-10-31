@font_style = {
  face: @doc.printable.customer.font_face,
  size: @doc.printable.customer.font_size.to_i
}
prawn_document do |pdf|
  pdf.define_grid(columns: 5, rows: 8, gutter: 10)
  pdf.font @font_style[:face], size: @font_style[:size]

  pdf.repeat(:all) do
    render 'spree/printables/shared/purchase_order/header', pdf: pdf, printable: @doc
  end

  # CONTENT
  pdf.grid([1,0], [6,4]).bounding_box do

    # address block on first page only
    if pdf.page_number == 1
      render 'spree/printables/shared/purchase_order/address_block', pdf: pdf, printable: @doc
      pdf.move_down 10

      #shipping_method = "<b>Shipping Method:</b> #{@doc.printable.shipping_method.try(:name)}"

      special_instructions = "<b>#{Spree.t(:special_instructions)}:</b> #{@doc.printable.special_instructions}"
      data = pdf.make_cell(content: special_instructions, inline_format: true)
      data.style(:leading => 6)
      pdf.table([[data]], position: :center, column_widths: [pdf.bounds.width])
    end

    pdf.move_down 10

    render 'spree/printables/shared/purchase_order/items', pdf: pdf, printable: @doc

    # pdf.move_down 30
    # pdf.text @doc.printable.customer.anomaly_message, align: :left, size: @font_style[:size]

    pdf.move_down 20
    # pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: 250) do
    #   pdf.transparent(0.5) { pdf.stroke_bounds }
    # end
  end

  # Footer
  if @doc.printable.customer.use_footer
    render 'spree/printables/shared/purchase_order/footer', pdf: pdf
  end

  # Page Number
  if @doc.printable.customer.use_page_numbers
    render 'spree/printables/shared/page_number', pdf: pdf
  end
end
