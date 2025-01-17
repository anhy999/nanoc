# frozen_string_literal: true

describe Nanoc::Core::ItemRepSelector do
  let(:selector) { described_class.new(reps_for_selector) }

  let(:item) do
    Nanoc::Core::Item.new('stuff', {}, '/foo.md')
  end

  let(:reps_array) do
    [
      Nanoc::Core::ItemRep.new(item, :a),
      Nanoc::Core::ItemRep.new(item, :b),
      Nanoc::Core::ItemRep.new(item, :c),
      Nanoc::Core::ItemRep.new(item, :d),
      Nanoc::Core::ItemRep.new(item, :e),
    ]
  end

  let(:reps_for_selector) { reps_array }

  let(:names_to_reps) do
    reps_array.each_with_object({}) do |rep, acc|
      acc[rep.name] = rep
    end
  end

  let(:dependencies) { {} }

  let(:result) do
    tentatively_yielded = []
    successfully_yielded = []
    selector.each do |rep|
      tentatively_yielded << rep.name

      dependencies.fetch(rep.name, []).each do |name|
        unless successfully_yielded.include?(name)
          raise Nanoc::Core::Errors::UnmetDependency.new(names_to_reps[name], :foo)
        end
      end

      successfully_yielded << rep.name
    end

    [tentatively_yielded, successfully_yielded]
  end

  let(:tentatively_yielded) { result[0] }
  let(:successfully_yielded) { result[1] }

  describe 'error' do
    context 'plain error' do
      subject { selector.each { |_rep| raise 'heh' } }

      it 'raises' do
        expect { subject }.to raise_error(RuntimeError, 'heh')
      end
    end

    context 'plain dependency error' do
      subject do
        idx = 0
        selector.each do |_rep|
          idx += 1

          raise Nanoc::Core::Errors::UnmetDependency.new(reps_array[2], :foo) if idx == 1
        end
      end

      it 'does not raise' do
        expect { subject }.not_to raise_error
      end
    end

    context 'wrapped error' do
      subject do
        selector.each do |rep|
          raise 'heh'
        rescue => e
          raise Nanoc::Core::Errors::CompilationError.new(e, rep)
        end
      end

      it 'raises original error' do
        expect { subject }.to raise_error(Nanoc::Core::Errors::CompilationError) do |err|
          expect(err.unwrap).to be_a(RuntimeError)
          expect(err.unwrap.message).to eq('heh')
        end
      end
    end

    context 'wrapped dependency error' do
      subject do
        idx = 0
        selector.each do |rep|
          idx += 1

          begin
            raise Nanoc::Core::Errors::UnmetDependency.new(reps_array[2], :foo) if idx == 1
          rescue => e
            raise Nanoc::Core::Errors::CompilationError.new(e, rep)
          end
        end
      end

      it 'does not raise' do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe 'cycle' do
    context 'dependency on self' do
      subject do
        selector.each { |r| raise Nanoc::Core::Errors::UnmetDependency.new(r, :foo) }
      end

      example do
        expect { subject }.to raise_error(Nanoc::Core::Errors::DependencyCycle, <<~EOS)
          The site cannot be compiled because there is a dependency cycle:

              (1) item /foo.md, rep :a, uses compiled content of (1)
        EOS
      end
    end

    context 'cycle with three dependencies' do
      subject do
        selector.each do |r|
          case r
          when reps_array[0]
            raise Nanoc::Core::Errors::UnmetDependency.new(reps_array[1], :foo)
          when reps_array[1]
            raise Nanoc::Core::Errors::UnmetDependency.new(reps_array[2], :foo)
          when reps_array[2]
            raise Nanoc::Core::Errors::UnmetDependency.new(reps_array[0], :foo)
          end
        end
      end

      example do
        expect { subject }.to raise_error(Nanoc::Core::Errors::DependencyCycle, <<~EOS)
          The site cannot be compiled because there is a dependency cycle:

              (1) item /foo.md, rep :a, uses compiled content of
              (2) item /foo.md, rep :b, uses compiled content of
              (3) item /foo.md, rep :c, uses compiled content of (1)
        EOS
      end
    end
  end

  describe 'yield order' do
    context 'linear dependencies' do
      let(:dependencies) do
        {
          a: [:b],
          b: [:c],
          c: [:d],
          d: [:e],
          e: [],
        }
      end

      example do
        expect(successfully_yielded).to eq %i[e d c b a]
        expect(tentatively_yielded).to eq %i[a b c d e d c b a]
      end
    end

    context 'no dependencies' do
      let(:dependencies) do
        {}
      end

      example do
        expect(successfully_yielded).to eq %i[a b c d e]
        expect(tentatively_yielded).to eq %i[a b c d e]
      end
    end

    context 'star dependencies' do
      let(:dependencies) do
        {
          a: %i[b c d e],
        }
      end

      example do
        expect(successfully_yielded).to eq %i[b c d e a]
        expect(tentatively_yielded).to eq %i[a b a c a d a e a]
      end
    end

    context 'star dependencies; selectively recompiling' do
      let(:reps_for_selector) { reps_array.first(1) }

      let(:dependencies) do
        {
          a: %i[b c d e],
        }
      end

      example do
        expect(successfully_yielded).to eq %i[b c d e a]
        expect(tentatively_yielded).to eq %i[a b a c a d a e a]
      end
    end

    context 'unrelated roots' do
      let(:dependencies) do
        {
          a: [:d],
          b: [:e],
          c: [],
        }
      end

      it 'picks prioritised roots' do
        expect(successfully_yielded).to eq %i[d a e b c]
        expect(tentatively_yielded).to eq %i[a d a b e b c]
      end
    end
  end
end
