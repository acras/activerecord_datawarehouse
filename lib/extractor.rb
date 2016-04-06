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

    def extract_by_id(id)
      puts "=> Importing #{@origin_model} by id: #{id.to_s}"
      r = @origin_model.find(id)
      update_dimension_main_attributes(r)
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

    def translate_field(r, params)
      fn = params[:field_name]
      v = translate_single_string(r, fn) if !(fn.include? '.')
      v = translate_nested_string(r, fn) if (fn.include? '.')

      default_value = params[:default_value]
      if default_value.to_s.strip != ''
        v = default_value if v.to_s.strip == ''
      end
      v
    end

    def translate_function(rec, func_name)
      send(func_name, rec)
    end

    def translate_date(rec, field_name, params = {})
      v = translate_nested_string(rec, field_name, nil)
      d = Datawarehouse::DateDimension.find_by_date(v.try :to_date)
      if !d && params[:ignore_out_of_bounds]
        d = Datawarehouse::DateDimension.find_by_date(nil)
        raise "No date in Date Dimension for #{v.try(:to_date).try(:strftime ,'%d/%m/%Y')} nor for the nil date" unless d
      end
      raise "No date in Date Dimension for #{v.try(:to_date).try(:strftime ,'%d/%m/%Y')}" unless d
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
      if params.is_a? String
        r = translate_single_string(rec, params) if !(params.include? '.')
        r = translate_nested_string(rec, params) if (params.include? '.')
      end
      if params.is_a? Array
        p_type = params[0]
        r = translate_function(rec, params[1]) if p_type == :function
        r = translate_date(rec, params[1], {}) if p_type == :date
        r = translate_time(rec, params[1]) if p_type == :time
        r = translate_dimension(rec, params[1], params[2]) if p_type == :dimension
        r = translate_with_default(rec, params[1], params[2]) if p_type == :with_default
      end
      if params.is_a? Hash
        p_type = params[:type] || :field
        r = translate_function(rec, params[:function_name]) if p_type == :function
        r = translate_date(rec, params[:field_name], params) if p_type == :date
        r = translate_time(rec, params[:field_name]) if p_type == :time
        r = translate_dimension(rec, params[1], params[2]) if p_type == :dimension
        r = translate_field(rec, params) if p_type == :field
      end
      r
    end

    def is_scd2?(config)
      r = false
      if config.is_a? Hash
        r = config[:scd_type] == 2
      end
      r
    end

    def update_dimension_main_attributes(r)
      # 1 - monta hash de updates com key e o valor já traduzido e já
      #     verifica se algum sd2 mudou
      # 3 - se algum sd2 mudou OU o registro não existia, cria
      # 4 - dá os sends como é feito hoje
      any_scd2_changed = false
      values = {}
      dr = @destination_model.where(original_id: r.id).last
      @attribute_mappings.each_pair do |k, v|
        values[k] = get_translated_value(r, v)
        if dr && (is_scd2? @attribute_mappings[k])
          any_scd2_changed ||= values[k] != dr.send(k.to_s)
        end
      end
      ActiveRecord::Base.transaction do
        if (!dr) || (any_scd2_changed)
          if dr
            #indicar que o registro encontrado não é mais o válido
            dr.is_last_version = false if dr.respond_to? 'is_last_version'
            dr.save
          end
          #criar o novo
          dr = @destination_model.new
          dr.is_last_version = true
        end
        @attribute_mappings.each_pair do |k, v|
          dr.send(k.to_s + '=', values[k])
        end
        dr.save
      end
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
      @origin_model.where(conditions).
          order('version ASC').
          limit(max_records).all
    end
  end
end
