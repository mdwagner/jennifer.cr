require "../spec_helper"

postgres_only do
  describe Jennifer::Adapter::Postgres do
    described_class = Jennifer::Adapter::Postgres
    adapter = Jennifer::Adapter.adapter.as(Jennifer::Adapter::Postgres)

    describe "#translate_type" do
      it "returns sql type associated with given synonim" do
        adapter.translate_type(:string).should eq("varchar")
      end
    end

    describe "#default_type_size" do
      it "returns default type size for given alias" do
        adapter.default_type_size(:string).should eq(254)
      end
    end

    describe "#parse_query" do
      it "replaces %s by dollar-and-numbers" do
        adapter.parse_query("some %s query %s", ["a", "b"]).should eq("some $1 query $2")
      end
    end

    describe "index manipulation" do
      age_index_options = {
        :type    => nil,
        :fields  => [:age],
        :order   => {} of Symbol => Symbol,
        :lengths => {} of Symbol => Symbol,
      }
      index_name = "contacts_age_index"

      context "#index_exists?" do
        it "returns true if exists index with given name" do
          adapter.index_exists?("", "contacts_description_index").should be_true
        end

        it "returns false if index is not exist" do
          adapter.index_exists?("", "contacts_description_index_test").should be_false
        end
      end

      context "#add_index" do
        it "should add a covering index if no type is specified" do
          delete_index_if_exists(adapter, index_name)

          adapter.add_index("contacts", index_name, age_index_options)
          adapter.index_exists?("", index_name).should be_true
        end
      end

      context "#drop_index" do
        it "should drop an index if it exists" do
          delete_index_if_exists(adapter, index_name)

          adapter.add_index("contacts", index_name, age_index_options)
          adapter.index_exists?("", index_name).should be_true

          adapter.drop_index("", index_name)
          adapter.index_exists?("", index_name).should be_false
        end
      end
    end

    describe "#change_column" do
      pending "add" do
      end
    end

    # Now those methods are tested by another cases
    describe "#exists?" do
      it "returns true if record exists" do
        Factory.create_contact
        adapter.exists?(Contact.all).should be_true
      end

      it "returns false if record doesn't exist" do
        adapter.exists?(Contact.all).should be_false
      end
    end

    describe "#insert" do
      it "stores given object to the db" do
        c = Factory.build_contact
        adapter.insert(c).last_insert_id.should_not eq(-1)
        Contact.all.first!
      end
    end

    describe "#material_view_exists?" do
      it "returns true if exists" do
        adapter.material_view_exists?("female_contacts").should be_true
      end

      it "returns false if doen't exist" do
        adapter.material_view_exists?("male_contacts").should be_false
      end
    end

    describe "#table_column_count" do
      context "given a materialized view name" do
        it "returns count of materialized view fields" do
          adapter.table_column_count("female_contacts").should eq(9)
        end
      end
    end

    describe "#refresh_materialized_view" do
      it "refreshes data on given MV" do
        Factory.create_contact(gender: "female")
        Factory.create_contact(gender: "male")
        FemaleContact.all.count.should eq(0)
        adapter.refresh_materialized_view(FemaleContact.table_name)
        FemaleContact.all.count.should eq(1)
      end
    end

    describe "#data_type_exists?" do
      it "returns true if given datatype exists" do
        adapter.data_type_exists?("gender_enum").should eq(true)
      end

      it "returns false if given datatype doesn't exists" do
        adapter.data_type_exists?("gender").should eq(false)
      end
    end

    describe "#enum_values" do
      it "returns values of given enum" do
        adapter.enum_values("gender_enum").should eq(%w(male female))
      end

      it "raises base exception if there is no given datatype" do
        expect_raises(Jennifer::BaseException) do
          adapter.enum_values("gender")
        end
      end
    end

    describe "#with_table_lock" do
      table = "contacts"

      it "starts table lock with given type" do
        adapter.with_table_lock(table, "as") { }
        query_log.any? { |entry| entry =~ /LOCK TABLE \w* IN ACCESS SHARE/ }.should be_true
      end

      it "starts table lock with given type" do
        adapter.with_table_lock(table) { }
        query_log.any? { |entry| entry =~ /LOCK TABLE \w* IN SHARE/ }.should be_true
      end

      it "raise BaseException if given invalid lock type" do
        expect_raises(Jennifer::BaseException) do
          adapter.with_table_lock(table, "gghhhh") { }
        end
      end
    end
  end
end

def delete_index_if_exists(adapter, index)
  adapter.drop_index("", index) if adapter.index_exists?("", index)
end
