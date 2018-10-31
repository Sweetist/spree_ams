vendor = @doc.printable.vendor
pdf.repeat(:all) do
  pdf.grid([footer_row_start,0], [7,4]).bounding_box do

    data  = []
    tac1 = nil
    tac2 = nil
    tac3 = nil
    tac12 = []
    sign_cols = vendor.bol_require_shipper_signature && vendor.bol_require_receiver_signature ? 4 : 2
    tac12_cols = vendor.bol_terms_and_condtions1.present? && vendor.bol_terms_and_condtions2.present? ? 2 : 4
    tac12_cols /=  2 if sign_cols == 2
    if vendor.bol_terms_and_condtions1.present?
      tac1 = pdf.make_cell(content: vendor.bol_terms_and_condtions1, colspan: tac12_cols)
      tac12 << tac1
    end
    if vendor.bol_terms_and_condtions2.present?
      tac2 = pdf.make_cell(content: vendor.bol_terms_and_condtions2, colspan: tac12_cols)
      tac12 << tac2
    end
    data << tac12 unless tac12.empty?
    if vendor.bol_terms_and_condtions3.present?
      tac3 = pdf.make_cell(content: vendor.bol_terms_and_condtions3, colspan: sign_cols)
      data << [tac3]
    else
      pdf.move_down 30
    end

    signatures = []
    if vendor.bol_require_shipper_signature
      signatures << pdf.make_cell(content: 'Shipper Signature', borders: [:top, :bottom, :left], valign: :bottom)
      signatures << pdf.make_cell(content: 'Date', borders: [:top, :bottom, :right], valign: :bottom)
    end
    if vendor.bol_require_receiver_signature
      signatures << pdf.make_cell(content: 'Receiver Signature', borders: [:top, :bottom, :left], valign: :bottom)
      signatures << pdf.make_cell(content: 'Date', borders: [:top, :bottom, :right], valign: :bottom)
    end

    data << signatures unless signatures.empty?

    col_widths = []
    sign_cols.times do |n|
      if sign_cols == 2
        col_widths << (pdf.bounds.width / sign_cols)
      else
        col_widths << (pdf.bounds.width / sign_cols) * (n.even? ? 1.3 : 0.7)
      end
    end
    pdf.table(data, position: :center, column_widths: col_widths,
      cell_style: { overflow: :shrink_to_fit, min_font_size: 4, height: 25, size: 8 }) do
      if tac12.present?
        row(0).style height: 75, padding: 2
        if vendor.bol_terms_and_condtions3.present?
          row(1).style height: 50, padding: 2
        end
      elsif vendor.bol_terms_and_condtions3.present?
        row(0).style height: 50, padding: 2
      end

    end
  end
end
