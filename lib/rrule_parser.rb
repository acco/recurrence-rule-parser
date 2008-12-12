require 'rubygems'
require 'runt'
require 'icalendar'

class RruleParser
  VERSION = '1.0.0'
  
  DAYS = {
    "SU" => Runt::Sunday,
    "MO" => Runt::Monday,
    "TU" => Runt::Tuesday,
    "WE" => Runt::Wednesday,
    "TH" => Runt::Thursday,
    "FR" => Runt::Friday,
    "SA" => Runt::Saturday,
    "SU" => Runt::Sunday
  }
  
  ADVERB_MAP = {
    "DAILY"   => "DAY",
    "WEEKLY"  => "WEEK",
    "MONTHLY" => "MONTH",
    "YEARLY"  => "YEAR"
  }
  
  attr_accessor :event
  attr_accessor :rules
  
  def initialize(event)
    @expressions      = []
    @count            = 0
    self.rules        = {}
    self.event        = event
    self.parse_rules(event)
    parse_count
  end
  
  # Parse rules, output temporal expressions
  def expressions        
    @expressions = []
    @expressions << parse_frequency_and_interval
    @expressions << send(:"parse_#{self.rules[:freq].downcase}")
    @expressions << parse_start
    @expressions << parse_until
    @expressions.compact!
    @expressions
  end
  
  def expression
    self.expressions.inject {|m, v| v & m}
  end
  
  # Accepts a range of dates and outputs an array of dates matching the temporal expression.
  def dates(range)
    dates = []
    
    if @count <= 0
      dates << self.expression.dates(range)
    else
      temp_range = (self.event.start.send :to_date)..(range.last)
      temp_dates = self.expression.dates(temp_range, @count)
      dates << temp_dates.select do |date|
        range.include?(date)
      end
    end
  
    # TODO put original date back in if recurrence rule doesn't define it.
    dates << self.event.start.send(:to_date)
    dates.flatten.uniq
  end
  
  protected
  
  def parse_rules(event)
    rrules = event.recurrence_rules
    rrules.each do |rule|
      pairs = rule.split(";")
      pairs.each do |pair|
        array = pair.split('=')
        self.rules[array[0].downcase.to_sym] = array[1]
      end
    end
    
    # Parse comma separated lists.
    self.rules.each do |key, rule|
      if rule =~ /,/
        rules[key] = rule.split(',')
      end
    end
  end
  
  def parse_start
    start_date = Date.civil(self.event.start.year, self.event.start.month, self.event.start.day) - 1
    Runt::AfterTE.new(start_date)
  end
  
  def parse_frequency_and_interval
    if self.rules[:freq]
      frequency = self.rules[:freq]
      interval  = self.rules[:interval] ? self.rules[:interval].to_i : 1
      Runt::EveryTE.new(self.event.start, interval, Runt::DPrecision.const_get(ADVERB_MAP[frequency]))
    end
  end
  
  def parse_daily
    # TODO: Support for daily recurrences
  end
  
  def parse_weekly
    if self.rules[:byday]
      self.rules[:byday].map { |day| Runt::DIWeek.new(RruleParser::DAYS[day]) }.inject do |m, expr|
        m | expr
      end
    else
      # Make the event recur on the day of the original event.
      Runt::DIWeek.new(self.event.start.wday)
    end
  end
  
  def parse_monthly
    if self.rules[:byday]
      # TODO: Support monthly byday
    elsif self.rules[:bymonthday]
      self.rules[:bymonthday].map { |day| Runt::REMonth.new(day.to_i) }.inject do |m, expr|
        m | expr
      end
    else
      Runt::REMonth.new(self.event.start.day, self.event.start.day)
    end
  end
  
  def parse_yearly
    # TODO: Support for yearly recurrences
  end
  
  
  def parse_until
    if self.rules[:until]
      Runt::BeforeTE.new(Date.parse(self.rules[:until]))
    end
  end
  
  def parse_count
    @count = self.rules[:count].to_i if self.rules[:count]
  end
end