class DateTime
  def floor(seconds = 60)
    return self if seconds <= 0
    Time.at((self.to_f / seconds).floor * seconds).utc.to_datetime
  end
end
