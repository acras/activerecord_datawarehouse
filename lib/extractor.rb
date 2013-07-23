module Datawarehouse
  class Extractor

    attr_accessor :origin_model, :destination_model, :attribute_mappings

    def extract
      puts "  Initializing model #{@destination_model}"
      before_extract if defined? before_extract
      ensure_nulls if defined? ensure_nulls
      puts "  ..Getting new records, limited by #{max_records.to_s}"
      continue = true
      begin 
        record_set = get_new_records
        puts "  ..Got #{record_set.count.to_s}"
        i = 1
        record_set.each do |r|
          puts "Importing #{@destination_model} id: #{r.id.to_s} - #{i.to_s}/#{record_set.count.to_s}"
          update_dimension_main_attributes(r)
          i += 1
        end
        continue = record_set.length == max_records
      end while continue
    end

    protected

    def ensure_nulls;end

    def translate_nested_string(r, field_name, default_value = 'nenhum')
      c = r
      path = field_name.split('.')
      i = 0
      while (i < path.size) and (c)
        c = c.send(path[i])
        i += 1
      end
      c || default_value
    end

    def translate_single_string(r, field_name)
      r.send(field_name)
    end

    def translate_function(rec, func_name)
      send(func_name, rec)
    end

    def translate_date(rec, field_name)
      v = translate_nested_string(rec, field_name, nil)
      d = Datawarehouse::DateDimension.find_by_date(v.to_date)
      raise "No date in Date Dimension for #{v.to_date.strftime('%d/%m/%Y')}" unless d
      d.id
    end

    def translate_time(rec, field_name)
      v = translate_nested_string(rec, field_name, nil)
      if v
        hour = v.strftime('%H').to_i
        minute = v.strftime('%N').to_i
        t = Datawarehouse::TimeDimension.find_by_hora_and_minuto(hour,minute)
      else
        t = Datawarehouse::TimeDimension.find_by_hora_and_minuto(nil, nil)
      end
      raise "No time in Time Dimension" unless t
      t.id
    end

    def get_translated_value(rec, params)
      r = ''
      r = translate_single_string(rec, params) if (params.is_a? String) and !(params.include? '.')
      r = translate_nested_string(rec, params) if (params.is_a? String) and (params.include? '.')
      if params.is_a? Array
        p_type = params[0]
        r = translate_function(rec, params[1]) if p_type == :function
        r = translate_date(rec, params[1]) if p_type == :date
        r = translate_time(rec, params[1]) if p_type == :time
        r = translate_dimension(rec, params[1], params[2]) if p_type == :dimension
      end
      r
    end

    def update_dimension_main_attributes(r)
      dr = @destination_model.find_by_original_id(r.id)
      dr = @destination_model.new unless dr
      @attribute_mappings.each_pair do |k, v|
        dr.send(k.to_s + '=', get_translated_value(r, v))
      end
      dr.save
    end

    def last_version
      @destination_model.maximum(:version, :conditions => get_max_conditions) || 0
    end

    def get_max_conditions
      []
    end

    def get_conditions
      ['(version > ?)', last_version]
    end
    
    def max_records
      1000
    end

  #get new and updated records, considering only the main model from the dimension
    def get_new_records
      conditions = get_conditions
      @origin_model.all(
          :conditions => conditions,
          :order => 'version ASC',
          :limit => max_records)
    end
  end
end
