require 'test_helper'

class KlassOne
  include PermaCache

  def method1
    sleep 1
    1
  end
  perma_cache :method1

  def method2
    sleep 1
    2
  end
  perma_cache :method2, :obj => :other_klass
  def method2_key
    "more things"
  end

  def method3
    sleep 1
    3
  end
  perma_cache :method3, :version => 2, :expires_in => 5

  def question?
    sleep 1
    4
  end
  perma_cache :question?

  def exclamation!
    sleep 1
    4
  end
  perma_cache :exclamation!

  def other_klass
    KlassTwo.new
  end
end

class KlassTwo
  include PermaCache

  def cache_key
    "some_other_class/123"
  end
end

class KlassThree
  include PermaCache

  def id
    234
  end
end

module ModuleOne
  class << self
    include PermaCache
    def module_one_method
      345
    end
    perma_cache :module_one_method
  end
end

class PermaCacheTest < Minitest::Test

  def test_invalid_keys_should_raise_an_exception
    assert_raises RuntimeError, "expected keys are [:expires_in, :obj, :version]" do
      KlassOne.class_eval do
        def invalid_key
        end
        perma_cache :invalid_key, :foobar => 123
      end
    end
  end

  context "build_key_from_object" do
    context  "for a class" do
      context "That responds to cache_key" do
        should "have a correct key" do
          klass = KlassTwo
          assert klass.new.respond_to?(:cache_key)
          assert_equal ["some_other_class/123"], PermaCache.build_key_from_object(klass.new)
        end
      end
      context "that doesn't respond to cache_key" do
        should "have a correct key" do
          klass = KlassOne
          assert !klass.new.respond_to?(:cache_key)
          assert_equal ["KlassOne"], PermaCache.build_key_from_object(klass.new)
        end
      end
      context "that doesn't respond to cache key and responds to id" do
        should "have a correct key" do
          klass = KlassThree
          assert !klass.new.respond_to?(:cache_key)
          assert klass.new.respond_to?(:id)
          assert_equal ["KlassThree", 234], PermaCache.build_key_from_object(klass.new)
        end
      end
    end
  end

  context "calling cache" do
    context "without setting a cache source" do
      setup do
        PermaCache.send :remove_instance_variable, :@cache rescue nil
      end
      should "raise" do
        assert_raises PermaCache::UndefinedCache do
          PermaCache.cache
        end
      end
    end
    context "after setting a cache source" do
      setup do
        PermaCache.cache = 123
      end
      should "return that cache source" do
        assert_equal 123, PermaCache.cache
      end
    end
  end

  context "KlassOne" do
    should "have some methods defined for :method1" do
      obj = KlassOne.new
      assert obj.respond_to?(:method1_base_key)
      assert obj.respond_to?(:method1_perma_cache_key)
      assert obj.respond_to?(:method1!)
      assert obj.respond_to?(:method1_get_perma_cache)
      assert obj.respond_to?(:method1_with_perma_cache)
      assert obj.respond_to?(:method1_without_perma_cache)
      assert obj.respond_to?(:method1_was_rebuilt?)
    end

    should "have some methods defined for :question?" do
      obj = KlassOne.new
      assert obj.respond_to?(:question_question_base_key)
      assert obj.respond_to?(:question_question_perma_cache_key)
      assert obj.respond_to?(:question_question!)
      assert obj.respond_to?(:question_question_get_perma_cache)
      assert obj.respond_to?(:question_with_perma_cache?)
      assert obj.respond_to?(:question_without_perma_cache?)
      assert obj.respond_to?(:question_question_was_rebuilt?)
    end

    should "have some methods defined for :exclamation!" do
      obj = KlassOne.new
      assert obj.respond_to?(:exclamation_exclamation_base_key)
      assert obj.respond_to?(:exclamation_exclamation_perma_cache_key)
      assert obj.respond_to?(:exclamation_exclamation!)
      assert obj.respond_to?(:exclamation_exclamation_get_perma_cache)
      assert obj.respond_to?(:exclamation_with_perma_cache!)
      assert obj.respond_to?(:exclamation_without_perma_cache!)
      assert obj.respond_to?(:exclamation_exclamation_was_rebuilt?)
    end

    should "calling #method1 should write and return the result if the cache is empty" do
      obj = KlassOne.new
      cache_obj = Object.new
      cache_obj.expects(:read).with(obj.method1_perma_cache_key).once.returns(nil)
      cache_obj.expects(:write).with(obj.method1_perma_cache_key, 1, :expires_in => nil).once
      PermaCache.cache = cache_obj
      obj.expects(:sleep).with(1).once
      assert_equal 1, obj.method1
      assert obj.method1_was_rebuilt?
    end

    should "calling #method1 should read the cache, but not write it, if the cache is present" do
      obj = KlassOne.new
      cache_obj = Object.new
      cache_obj.expects(:read).with(obj.method1_perma_cache_key).once.returns(123)
      cache_obj.expects(:write).never
      PermaCache.cache = cache_obj
      obj.expects(:sleep).never
      assert_equal 123, obj.method1
      assert !obj.method1_was_rebuilt?
    end

    should "calling #method1! should write the cache, but not read from it" do
      obj = KlassOne.new
      cache_obj = Object.new
      cache_obj.expects(:read).never
      cache_obj.expects(:write).with(obj.method1_perma_cache_key, 1, :expires_in => nil).once
      PermaCache.cache = cache_obj
      obj.expects(:sleep).with(1).once
      assert_equal 1, obj.method1!
      assert obj.method1_was_rebuilt?
    end
  end
  context "version option" do
    should "add that key/value to the cache key" do
      assert_equal "perma_cache/v1/KlassOne/v2/method3", KlassOne.new.method3_perma_cache_key
    end
  end
  context "user defined keys" do
    should "should append themselves to the cache key" do
      assert_equal "perma_cache/v1/KlassOne/some_other_class/123/more_things/method2", KlassOne.new.method2_perma_cache_key
    end
  end
  context "setting expires_in" do
    should "pass the value through to #write" do
      obj = KlassOne.new
      cache_obj = Object.new
      cache_obj.expects(:read).with(obj.method3_perma_cache_key).returns(nil).once
      cache_obj.expects(:write).with(obj.method3_perma_cache_key, 3, :expires_in => 5).once
      obj.expects(:sleep).with(1).once
      PermaCache.cache = cache_obj
      obj.method3
    end
  end

  context "a module" do
    should "set the perma cache key" do
      assert_equal "perma_cache/v1/ModuleOne/module_one_method", ModuleOne.module_one_method_perma_cache_key
    end
  end
end

