#coding: utf-8

class DateDimensionGenerator

  attr_accessor :initial_date, :final_date, :dimension_class

  def generate
    #criar a data nula
    @dimension_class.create(:descriptive_date => 'Data não informada') unless @dimension_class.exists?(date: nil)
    #criar as datas na faixa solicitada
    initial_date.upto(final_date) do |d|
      puts '--Generating ' + d.strftime('%d/%m/%Y') + '--'
      r = date_to_dimension(d)
      d = @dimension_class.find_by_date(d)
      if d
        d.update_attributes(r)
        puts '  updated'
      else
        @dimension_class.create(r)
        puts '  created'
      end

    end
  end

  def date_to_dimension(d)
    r = {}
    r[:date] = d
    r[:descriptive_date] = get_descriptive_date(d)
    r[:numeric_day_in_week] = d.cwday
    r[:descriptive_day_in_week] = get_descriptive_day_in_week(d.cwday)
    r[:weekday] = weekday?(d.wday)
    r[:weekend] = weekend?(d.wday)
    r[:numeric_week_in_year] = d.cweek
    r[:numeric_day_in_month] = d.day
    r[:bimester] = (d.month+1) / 2
    r[:semester] = (d.month <= 6) ? 1 : 2
    r[:quarter] = (d.month+3) /
    r[:numeric_day_in_year] = d.yday
    r[:numeric_year] = d.year
    r[:numeric_month] = d.month
    r[:descriptive_month] = get_descriptive_month(d.month)

    if defined? get_extra_date_info
      r = r.merge(get_extra_date_info(d))
    end

    r
  end

  def get_descriptive_date(d)
    get_descriptive_day_in_week(d.cwday) + ', ' + d.day.to_s + ' de ' +
      get_descriptive_month(d.month) + ' de ' + d.year.to_s
  end

  def get_descriptive_day_in_week(wday)
    raise 'Invalid week day: ' + wday.to_s if wday < 1 or wday > 7
    case wday
      when 1 then 'Segunda-feira'
      when 2 then 'Terça-feira'
      when 3 then 'Quarta-feira'
      when 4 then 'Quinta-feira'
      when 5 then 'Sexta-feira'
      when 6 then 'Sábado'
      when 7 then 'Domingo'
    end
  end

  def weekday?(wday)
    (wday > 0) and (wday < 6)
  end

  def weekend?(wday)
    (wday > 5)
  end

  def get_descriptive_month(month)
    raise 'Invalid month' if month < 0 or month > 12
    case month
      when 1 then 'Janeiro'
      when 2 then 'Fevereiro'
      when 3 then 'Março'
      when 4 then 'Abril'
      when 5 then 'Maio'
      when 6 then 'Junho'
      when 7 then 'Julho'
      when 8 then 'Agosto'
      when 9 then 'Setembro'
      when 10 then 'Outubro'
      when 11 then 'Novembro'
      when 12 then 'Dezembro'
    end
  end

end
