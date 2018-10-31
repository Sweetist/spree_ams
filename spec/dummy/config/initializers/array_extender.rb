# Extend array with methods
class Array
  def distinct
    uniq
  end

  def select_as_hash(*opts)
    collect do |i|
      has = {}
      opts.each { |key| has[key.to_s] = i.send(key) }
      has
    end
  end

  def pluck(*opts)
    result = collect do |i|
      arr = []
      opts.each { |key| arr << i.send(key) }
      arr
    end

    return [] if result.blank?
    return result.flatten if result.first.size == 1

    result
  end

  def where(opts)
    keys = opts.keys
    select do |i|
      case keys.count
      when 1
        i.send(keys[0]) == opts[keys[0]]
      when 2
        i.send(keys[0]) == opts[keys[0]] \
        && i.send(keys[1]) == opts[opts.keys[1]]
      end
    end
  end
end
