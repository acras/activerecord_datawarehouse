class SlowlyChangingDimension1

  attr_accessor :model_field_mappings

  def update_all
    puts 'Processing slowly changing attributes type 1'
    @model_field_mappings.each do |mfm|
      model_class = mfm[0]
      mappings = mfm[1]
      puts "  CLASS: #{model_class.to_s}"
      records = get_new_records(model_class)
      records.each { |r| update_record(mappings, r) }
    end
  end

  def update_record(mappings, r)
    puts "    #{r.id.to_s}"
    mappings.each do |mapping|
      value = r.send(mapping[3])
      mapping[0].update_all(
          ["#{mapping[2]} = ?", value],
          ["#{mapping[1]} = ?", r.id])
    end
    set_or_create(r.class, r.version)
  end

  def get_new_records(model_class)
    model_class.all(:conditions => get_conditions(model_class), :order => 'version ASC')
  end

  def get_conditions(model_class)
    max_version = get_last_version_by_model(model_class)
    ['version > ?', max_version]
  end

  def get_last_version_by_model(model_class)
    r = get_record_by_model(model_class)
    r ? r.last_imported_version : 0
  end

  def set_or_create(model_class, version)
    tn = model_class.table_name
    r = get_record_by_model(model_class)
    if r
      r.last_imported_version = version
      r.save
    else
      r = Datawarehouse::LastVersionMap.create({:table_name => tn, :last_imported_version => version})
    end
    r
  end

  def get_record_by_model(model_class)
    tn = model_class.table_name
    Datawarehouse::LastVersionMap.first(:conditions => ['table_name like ?', tn])
  end

end
