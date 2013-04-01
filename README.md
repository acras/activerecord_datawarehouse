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
