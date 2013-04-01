activerecord_datawarehouse
==========================

What is the goal of this gem?
=====

The main goal of this gem is to provide basic classes for the extraction of data from ActiveRecord models into a datawarehouse database.
It´s main features are:

* DateDimension basic generation class
* TimeDimension basic generation class
* Dimension extractor basic class
* Fact extractor basic class
* Migration of the datawarehouse database with sepparate migrations from transactional database

Prerequisites
=====

* You should be using Activerecord, needless to say that right?
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
```

activerecord_datawarehouse provides a basic class to define how data will be extracted, the DimensionExtractor class

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
