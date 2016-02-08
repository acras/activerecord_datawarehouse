activerecord_datawarehouse
==========================

What is the goal of this gem?
=====

The main goal of this gem is to provide basic classes for the extraction of data from ActiveRecord models into a datawarehouse database.
It´s main features are:

* DateDimension basic generation class
* TimeDimension basic generation class
* Dimension extractor basic class
* Handle of slowly changing dimensions of types 1 and 2
* Fact extractor basic class
* Migration of the datawarehouse database with sepparate migrations from transactional database

Prerequisites
=====

* You should be using Activerecord
* You should be using Activerecord id patterns, not natural primary keys
* Every record have to have a version control, meaning it have a integer field that is incremented for every inclusion and change in the record. That is usefull to the extractors to know what has changed since last extraction.

How to use this gem?
=====

First off you should include the gem in your Gemfile.

```ruby
gem 'activerecord_datawarehouse'
```

As of almost every datawarehouse you could imagine, you´ll need date and time dimensions. activerecord-datawarehouse provides two basic classes for that: DateDimensionGenerator and TimeDimensionGenerator. No i18n yet, sorry, but hey most likely I´ll be the only one to use this gem, if needed contact-me.
Date dimensions could, and probably will, have specific attributes in your project. In this case you can inherit from these classes and define get_extra_date_info, like the following example:

```ruby
  def get_extra_date_info(d)
    r = {}
    r[:season] = get_season_description(d)
    r
  end
```

You can create rake tasks to generate these dimensions, like this:
Note: FLDateDimension is my inherited Date dimension extractor, you could use the default.
Note2: All the rake tasks related to Datawarehouse should be under datawarehouse namespace for the sake of organization.

```ruby
namespace :datawarehouse do
  desc "Generates date dimensions from January 2000 to December 2020"
  task(:generate_date_dimension => :environment) do
    fldw = FLDateDimensionGenerator.new
    fldw.initial_date = Date.parse('2000-01-01')
    fldw.final_date = Date.parse('2020-12-31')
    fldw.dimension_class = Datawarehouse::DateDimension
    fldw.generate
  end
end
```

Well, now it´s time to define your application dimension extractors. Let´s say you have a Product model in your application and it belongs to a Department. These models are defined as follows:

```
Product
  code
  barcode
  description
  brand_name
  department_id
  main_product_id
  version

Department
  name
```

...and you want your dimension to be like:

```
ProductDimension
  code
  barcode
  description
  brand_name
  department_description
  is_dimensioned
```

in the database you have to have some control fields, as shown bellow

```ruby
  create_table "product_dimensionss" do |t|
    t.integer "store_chain_id", :null => false
    t.string "code",  :limit => 100, :null => false
    t.string "barcode", :limit => 100, :null => false
    t.string "brand_name", :limit => 100, :null => false
    t.boolean "is_dimensioned"
    t.string "department_description", :limit => 100, :null => false
    t.integer "department_id"
    t.integer "version"
  end
```

ok, as you can see there´s a department_id in the field list. It is used to make a link to the department record in the transactional database. This is half the way to handle changes in the transactional database. Let´s say the department description is edited, but not the product record, activerecord_datawarehouse knows that it must update this dimension based on a helper table named last_version_maps, that keeps track of last version imported from every model in transactiona database and replicates changes to dw models.

Now let´s extract some data. activerecord_datawarehouse provides a basic class to define how data will be extracted, the DimensionExtractor class

First of all you can inherit from this class to set some behaviour, see the commented class bellow. FLDimensionExtractor will be the super class for every dimension extractor class in this application
Note: Again, for the sake of organization we always use Datawarehouse module.

```ruby

module Datawarehouse
  class FLDimensionExtractor < DimensionExtractor

    def ensure_nulls
      #  ensure_nulls is used to fill dimension ids in fact tables when there is no dimension associated
      # as it is a datawarehouse prerogative in dw that no dimension should be null.
      #  For instance, if some trade has no product associted it´s producy_dimension_id should point
      # to a special ProductDimension record with description 'No product associated'.
      #  This method is responsible to ensure that this special record exists and is unique per dimension model.
    end

    def get_max_conditions
      #defines the way that the maximum version is gathered for this dimension. As saas apps always
      #run multiple customer data in the same database, generally there is a filtering field, in this example
      #it is the store_chain_id
      ['store_chain_id = ?', @store_chain_id]
    end

    def get_conditions
      #how do we get records, considering the filtering field
      r = super
      r[0] = r[0] + 'AND (store_chain_id = ?)'
      r << @store_chain_id
      r
    end

    def extract_for_store_chain(store_chain_id)
      #special function defined to extract only a specific customer info.
      #it is better to extract customer info sepparately
      @store_chain_id = store_chain_id
      extract
    end
  end
```

Once we have our main class setted, let´s write our extractor. We recommend that you define all your datawarehouse models under da Datawarehouse module and set the extrator as a subclass of the activerecord datawarehouse model. For our product example it would be like

```ruby
module Datawarehouse
  class ProductDimension < ActiveRecord::Base
    establish_connection "dw_#{Rails.env}" #we use a sepparate database

    class ProductDimensionExtractor < FocusLojasDimensionExtractor

      def initialize
        @origin_model = Product #from wich model at the transactional database we will be extracting
        @destination_model = ProductDimension #to wich model in the datawarehouse database we will be extracting

        @attribute_mappings = {
            description: {field_name: 'description', default_value: '<unset>'},
            code: 'code',
            barcode: 'barcode',
            original_id: 'id',
            version: 'version',
            store_chain_id: 'store_chain_id',
            is_dimensioned: {type: :function, function_name: 'is_dimensioned?'},
            department_name: 'department.name',
            department_id: 'department_id',
        }
      end

      def is_dimensioned?(r)
        !r.main_product.nil?
      end

    end
  end
end
```

As you can imagine, the key here is in the @attribute_mappings attribute. It is a hash that defines how data is extracted from the transactional model to the datawarehouse model. It has some types:

* field: It's the default type, can be defined as a single string or via a config Hash. Could be the name of an attribute or nested attributes, so you can use belongs_to, has_many and has_one in here. Like in the department.name example. This kind of attribute supports a default_value key.
* date: Refers to the date dimension. It is defined as an array of 2 elements where the first one is the type :date and the second one is the name of the date field. The gem will find the proper date dimension record to link to.
* time: Same as date, but to the Time Dimension
* dimension: When it refers to another dimension.
* function: Last resource, you want to write a funcion to get this field value. Your function will receive the entire record to handle as it wished. Look at is_dimensioned? above.

Slowly Changing Dimensions
==========

By defalut all attributes are managed like SCD type 1. If you want it to be treated as SCD type 2 set the key scd_type to 2. When an attribute is of type 2, the extractor will:

1 - Find out if on an update any scd type 2 attributes has changed
If any scd type 2 has changed it will
  1.1 - Create a new record
  1.2 - If there is a valid_from field on the dimension it will fill it with the updated_at date of the original record
  1.3 - If there is a valid_until field on the dimension it will fill the last valid record with the updated_at date of the original record
  1.4 - If there is a is_last_version field on the dimension it will fill the new record with true and all other records that represents the same dimension value to false
Else
  1.1 - Update all attributes from the last valid record for this dimension value or create a new record if it doesn't exist



Track changes in nested Models (SCD1 supported)
==========

activerecord_datawarehouse provides a class named SlowlyChangingDimension1. It is intended to handle this kind of changing dimensions.
In your project you will need to inherit it to add some behaviour. The example bellow shows it:

```ruby
module Datawarehouse

  class FLSlowlyChangingDimension1 < SlowlyChangingDimension1

    attr_accessor :store_chain_id

    def initialize
      @model_field_mappings = [
          [Department,
           [[ProductDimension, 'department_id', 'department_name', 'name']]
          ]
      ]
    end

    def get_new_records(model_class)
      #if you need to, this is your chance to change the way it gets new records
      super(model_class)
    end

    def update_all_for_store_chain(store_chain_id)
      @store_chain_id = store_chain_id
      update_all
    end

    def get_conditions(model_class)
      r = super(model_class)
      r[0] += ' AND (store_chain_id = ?)'
      r << @store_chain_id
      r
    end

    def set_or_create(model_class, version)
      r = super(model_class, version)
      r.store_chain_id = @store_chain_id
      r.save
      r
    end

    def get_record_by_model(model_class)
      tn = model_class.table_name
      LastVersionMap.first(
          :conditions => ['(table_name like ?) AND (store_chain_id = ?)', tn, @store_chain_id])
    end

  end
end
```

In the example above we have changed the way the gem gets records to include the store chain attribute. Furthermore we are setting the tuples that will tell the engine what should be looked at and updated as a slow changing dimension.
@model_field_mappings defines this.
