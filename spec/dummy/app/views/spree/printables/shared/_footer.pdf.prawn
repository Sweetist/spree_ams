pdf.repeat(:all) do
  pdf.grid([7,0], [7,4]).bounding_box do

    data  = []
    data << [pdf.make_cell(content: @doc.printable.vendor.footer_left,  align: :left),
    pdf.make_cell(content: @doc.printable.vendor.footer_right, align: :right)]

    pdf.table(data, position: :center, column_widths: [pdf.bounds.width / 2, pdf.bounds.width / 2]) do
      row(0..2).style borders: []
    end
  end
end
