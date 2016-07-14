require 'spec_helper'

RSpec.describe ROM::SQL::Association::ManyToMany do
  subject(:assoc) {
    ROM::SQL::Association::ManyToMany.new(:tasks, :tags, through: :task_tags)
  }

  include_context 'users and tasks'

  let(:tasks) { container.relations[:tasks] }
  let(:tags) { container.relations[:tags] }

  { postgres: POSTGRES_DB_URI, sqlite: SQLITE_DB_URI }.each_pair do |adapter, db_uri|
    context "with #{adapter} adapter", adapter: adapter do
      let(:uri) { db_uri }

      before do
        configuration.relation(:task_tags) do
          schema do
            attribute :task_id, ROM::SQL::Types::ForeignKey(:tasks)
            attribute :tag_id, ROM::SQL::Types::ForeignKey(:tags)

            primary_key :task_id, :tag_id

            associations do
              many_to_one :tasks
              many_to_one :tags
            end
          end
        end

        configuration.relation(:tasks) do
          schema do
            attribute :id, ROM::SQL::Types::Serial
            attribute :user_id, ROM::SQL::Types::ForeignKey(:users)
            attribute :title, ROM::SQL::Types::String

            associations do
              one_to_many :task_tags
              one_to_many :tags, through: :task_tags
            end
          end
        end
      end

      describe '#result' do
        specify { expect(ROM::SQL::Association::ManyToMany.result).to be(:many) }
      end

      describe '#call' do
        it 'prepares joined relations' do
          relation = assoc.call(container.relations)

          expect(relation.attributes).to eql(%i[id name task_id])
          expect(relation.to_a).to eql([id: 1, name: 'important', task_id: 1])
        end
      end

      describe '#combine_keys' do
        it 'returns key-map used for in-memory tuple-combining' do
          expect(assoc.combine_keys(container.relations)).to eql(id: :task_id)
        end
      end

      describe '#join_keys' do
        it 'returns key-map used for joins' do
          expect(assoc.join_keys(container.relations)).to eql(
            ROM::SQL::QualifiedName.new(:tasks, :id) => ROM::SQL::QualifiedName.new(:task_tags, :task_id)
          )
        end
      end

      describe ':through another assoc' do
        subject(:assoc) do
          ROM::SQL::Association::ManyToMany.new(:users, :tags, through: :tasks)
        end

        it 'prepares joined relations through other association' do
          relation = assoc.call(container.relations)

          expect(relation.attributes).to eql(%i[id name user_id])
          expect(relation.to_a).to eql([id: 1, name: 'important', user_id: 2])
        end
      end

      describe ROM::Plugins::Relation::SQL::AutoCombine, '#for_combine' do
        it 'preloads relation based on association' do
          relation = tags.for_combine(assoc).call(tasks.call)

          expect(relation.to_a).to eql([id: 1, name: 'important', task_id: 1])
        end
      end
    end
  end
end