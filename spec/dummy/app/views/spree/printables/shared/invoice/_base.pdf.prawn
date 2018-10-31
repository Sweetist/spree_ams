font_style = {
  face: @doc.printable.vendor.font_face,
  size: @doc.printable.vendor.font_size.to_i
}
prawn_document do |pdf|

  pdf.define_grid(columns: 5, rows: 8, gutter: 10)
  pdf.font font_style[:face], size: font_style[:size]

  pdf.repeat(:all) do
    render 'spree/printables/shared/header', pdf: pdf, printable: doc
  end

  # CONTENT
  pdf.grid([1,0], [6,4]).bounding_box do
    pdf.move_down 10
    # address block on first page only
    if pdf.page_number == 1
      render 'spree/printables/shared/address_block', pdf: pdf, printable: @doc
      pdf.move_down 10

      if !@doc.printable.multi_order?
        shipments = @doc.printable.orders.first.try(:shipments)
        tracking_numbers = shipments.present? ? shipments.pluck(:tracking).join(', ') : ''
        tracking = "<b>Tracking Number:</b> #{tracking_numbers}"
        special_instructions = "<b>#{Spree.t(:special_instructions)}:</b> #{@doc.printable.orders.first.try(:special_instructions)}<\n#{tracking}"
        data = pdf.make_cell(content: special_instructions, inline_format: true)
        data.style(:leading => 6)
        pdf.table([[data]], position: :center, column_widths: [pdf.bounds.width])
      end
    end

    pdf.move_down 10

    render 'spree/printables/shared/invoice/items', pdf: pdf, invoice: @doc

    pdf.move_down 10

    render 'spree/printables/shared/totals', pdf: pdf, invoice: @doc

    pdf.move_down 20

    pdf.text @doc.printable.vendor.return_message, align: :right, size: font_style[:size]
  end

  # Footer
  if @doc.printable.vendor.use_footer
    render 'spree/printables/shared/footer', pdf: pdf
  end

  # Page Number
  if @doc.printable.vendor.use_page_numbers
    render 'spree/printables/shared/page_number', pdf: pdf
  end

end
