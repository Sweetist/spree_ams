module ActiveSupport
  module NumberHelper
    class NumberToRoundedConverter

      def convert
        precision = options.delete :precision
        significant = options.delete :significant

        case number
        when Float, String
          @number = BigDecimal(number.old_to_s)
        when Rational
          @number = BigDecimal(number, digit_count(number.to_i) + precision)
        else
          @number = number.to_d
        end

        if significant && precision > 0
          digits, rounded_number = digits_and_rounded_number(precision)
          precision -= digits
          precision = 0 if precision < 0 # don't let it be negative
        else
          rounded_number = number.round(precision)
          rounded_number = rounded_number.to_i if precision == 0 && rounded_number.finite?
          rounded_number = rounded_number.abs if rounded_number.zero? # prevent showing negative zeros
        end

        formatted_string =
          if BigDecimal === rounded_number && rounded_number.finite?
            s = rounded_number.old_to_s('F') + '0'*precision
            a, b = s.split('.', 2)
            a + '.' + b[0, precision]
          else
            "%00.#{precision}f" % rounded_number
          end

        delimited_number = NumberToDelimitedConverter.convert(formatted_string, options)
        format_number(delimited_number)
      end
    end
  end
end
