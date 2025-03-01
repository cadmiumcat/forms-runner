require "rails_helper"

RSpec.describe Step do
  subject(:step) do
    described_class.new(
      question:,
      page:,
      form:,
      next_page_slug: "next-page",
      page_slug: "current-page",
    )
  end

  let(:question) { instance_double(Question::Text, serializable_hash: {}, attribute_names: %w[name], valid?: true) }
  let(:page) { build(:page, id: 2, position: 1, routing_conditions: []) }
  let(:form_context) { instance_double(Flow::FormContext) }
  let(:form) { build(:form, id: 3, form_slug: "test-form", pages: [page]) }

  describe "#initialize" do
    it "sets the attributes correctly" do
      expect(step.question).to eq(question)
      expect(step.page_id).to eq(2)
      expect(step.page_slug).to eq("current-page")
      expect(step.form_id).to eq(3)
      expect(step.form_slug).to eq("test-form")
      expect(step.next_page_slug).to eq("next-page")
      expect(step.page_number).to eq(1)
      expect(step.routing_conditions).to eq([])
    end
  end

  describe "#==" do
    it "returns true for steps with the same state" do
      other_step = described_class.new(
        question:,
        page:,
        form:,
        next_page_slug: "next-page",
        page_slug: "current-page",
      )
      expect(step).to eq(other_step)
    end

    it "returns false for steps with different states" do
      form = build :form, id: 4, form_slug: "other-form"
      other_step = described_class.new(
        question:,
        page:,
        form:,
        next_page_slug: "other-page",
        page_slug: "other-current-page",
      )
      expect(step == other_step).to be false
    end
  end

  describe "#state" do
    it "returns an array of instance variable values" do
      expected_state = [
        step.form,
        step.page,
        step.question,
        step.next_page_slug,
        step.page_slug,
      ]

      expect(step.state).to match_array(expected_state)
    end

    it "changes when an instance variable is modified" do
      original_state = step.state.dup
      step.form = build :form, pages: [step.page]
      expect(step.state).not_to eq(original_state)
    end
  end

  describe "#save_to_context" do
    it "saves the step to the form context" do
      expect(question).to receive(:before_save)
      expect(form_context).to receive(:save_step).with(step, {})
      step.save_to_context(form_context)
    end
  end

  describe "#load_from_context" do
    it "loads the step from the form context" do
      allow(form_context).to receive(:get_stored_answer).with(step).and_return({ name: "Test" })
      expect(question).to receive(:assign_attributes).with({ name: "Test" })
      step.load_from_context(form_context)
    end
  end

  describe "#update!" do
    it "assigns attributes and validates the question" do
      params = { name: "New Name" }
      expect(question).to receive(:assign_attributes).with(params)
      expect(question).to receive(:valid?)
      step.update!(params)
    end
  end

  describe "#params" do
    it "returns question attribute names with selection" do
      expect(step.params).to eq(["name", { selection: [] }])
    end
  end

  describe "#clear_errors" do
    it "clears errors on the question" do
      errors = instance_double(ActiveModel::Errors)
      allow(question).to receive(:errors).and_return(errors)
      expect(errors).to receive(:clear)
      step.clear_errors
    end
  end

  describe "#end_page?" do
    context "when next_page_slug is nil" do
      subject(:step) do
        described_class.new(question:, page:, form:, next_page_slug: nil, page_slug: "current-page")
      end

      it { is_expected.to be_end_page }
    end

    context "when next_page_slug is not nil" do
      it { is_expected.not_to be_end_page }
    end
  end

  describe "#next_page_slug_after_routing" do
    let(:default_next_page) { "next-page" }
    let(:selection) { "Yes" }
    let(:question) { instance_double(Question::Selection, selection:) }
    let(:routing_conditions) { [] }
    let(:page) { build(:page, id: 2, position: 1, routing_conditions:) }

    describe "basic routing" do
      context "without any routing conditions" do
        let(:selection) { "Any" }

        it "returns the next_page_slug when routing_conditions is empty" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end

      context "without conditions" do
        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end
    end

    describe "single condition routing" do
      context "with a matching condition" do
        let(:selection) { "Yes" }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "Yes", goto_page_id: "5")] }

        it "returns the goto_page_id of the condition" do
          expect(step.next_page_slug_after_routing).to eq("5")
        end
      end

      context "with a non-matching condition" do
        let(:selection) { "No" }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "Yes", goto_page_id: "5")] }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with a non-selection question and a default condition" do
        let(:question) { instance_double(Question::Text, :with_answer) }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "", goto_page_id: "5")] }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq("5")
        end
      end

      context "with a non-selection question and a match condition" do
        let(:question) { instance_double(Question::Text, :with_answer) }
        let(:routing_conditions) { [OpenStruct.new(answer_value: "something", goto_page_id: "5")] }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end
    end

    describe "skip_to_end routing" do
      context "with skip_to_end and no goto_page_id" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: nil, skip_to_end: true),
          ]
        end
        let(:selection) { "Yes" }

        it "returns the check your answers page slug" do
          expect(step.next_page_slug_after_routing).to eq(CheckYourAnswersStep::CHECK_YOUR_ANSWERS_PAGE_SLUG)
        end
      end

      context "with skip_to_end and goto_page_id" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: 7, skip_to_end: true),
          ]
        end
        let(:selection) { "Yes" }

        it "prioritizes goto_page_id over skip_to_end" do
          expect(step.next_page_slug_after_routing).to eq("7")
        end
      end
    end

    describe "with invalid states" do
      context "with multiple conditions and second matches" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "No", goto_page_id: "5"),
            OpenStruct.new(answer_value: "Yes", goto_page_id: "6"),
            OpenStruct.new(answer_value: "Maybe", goto_page_id: "7"),
          ]
        end
        let(:selection) { "Yes" }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with multiple conditions and second is default" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "No", goto_page_id: "5"),
            OpenStruct.new(answer_value: "Yes", goto_page_id: "6"),
            OpenStruct.new(answer_value: "", goto_page_id: "7"),
          ]
        end
        let(:selection) { "Something else" }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with multiple conditions but no matches" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: "5"),
            OpenStruct.new(answer_value: "No", goto_page_id: "6"),
            OpenStruct.new(answer_value: "Maybe", goto_page_id: "7"),
          ]
        end
        let(:selection) { "Something Else" }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end

      context "with nil selection" do
        let(:routing_conditions) do
          [
            OpenStruct.new(answer_value: "Yes", goto_page_id: "5"),
          ]
        end
        let(:selection) { nil }

        it "returns the next_page_slug" do
          expect(step.next_page_slug_after_routing).to eq(default_next_page)
        end
      end
    end
  end

  describe "#repeatable?" do
    it "returns false" do
      expect(step.repeatable?).to be false
    end
  end

  describe "#skipped?" do
    it "returns true if question is optional and show_answer is blank" do
      allow(question).to receive_messages(
        is_optional?: true,
        show_answer: "",
      )
      expect(step.skipped?).to be true
    end

    it "returns false if is_optional? is false" do
      allow(question).to receive_messages(
        is_optional?: false,
        show_answer: "",
      )
      expect(step.skipped?).to be false
    end

    it "returns false if show_answer is not blank" do
      allow(question).to receive_messages(
        is_optional?: true,
        show_answer: "something",
      )
      expect(step.skipped?).to be false
    end
  end

  shared_examples "delegates to question" do |method_name|
    it "delegates #{method_name} to question" do
      expect(question).to receive(method_name)
      step.send(method_name)
    end
  end

  describe "#valid?" do
    it_behaves_like "delegates to question", :valid?
  end

  describe "#show_answer" do
    it_behaves_like "delegates to question", :show_answer
  end

  describe "#show_answer_in_email" do
    it_behaves_like "delegates to question", :show_answer_in_email
  end

  describe "#show_answer_in_csv" do
    it_behaves_like "delegates to question", :show_answer_in_csv
  end

  describe "#question_text" do
    it_behaves_like "delegates to question", :question_text
  end

  describe "#hint_text" do
    it_behaves_like "delegates to question", :hint_text
  end

  describe "#answer_settings" do
    it_behaves_like "delegates to question", :answer_settings
  end

  describe "#conditions_with_goto_errors" do
    let(:cannot_have_goto_page_before_routing_page_error) { OpenStruct.new(name: "cannot_have_goto_page_before_routing_page") }
    let(:goto_page_doesnt_exist_error) { OpenStruct.new(name: "goto_page_doesnt_exist") }
    let(:other_error) { OpenStruct.new(name: "some_other_error") }

    context "when there are no routing conditions" do
      let(:routing_conditions) { [] }
      let(:page) { build(:page, id: 2, position: 1, routing_conditions: routing_conditions) }

      it "returns an empty array" do
        expect(step.conditions_with_goto_errors).to be_empty
      end
    end

    context "when routing conditions have no errors" do
      let(:condition) { OpenStruct.new(validation_errors: []) }
      let(:routing_conditions) { [condition] }
      let(:page) { build(:page, id: 2, position: 1, routing_conditions: routing_conditions) }

      it "returns an empty array" do
        expect(step.conditions_with_goto_errors).to be_empty
      end
    end

    context "when routing conditions have relevant errors" do
      let(:condition) { OpenStruct.new(validation_errors: [cannot_have_goto_page_before_routing_page_error]) }
      let(:second_condition) { OpenStruct.new(validation_errors: [goto_page_doesnt_exist_error]) }
      let(:routing_conditions) { [condition, second_condition] }
      let(:page) { build(:page, id: 2, position: 1, routing_conditions: routing_conditions) }

      it "returns conditions with specified errors" do
        expect(step.conditions_with_goto_errors).to contain_exactly(condition, second_condition)
      end
    end

    context "when routing conditions have irrelevant errors" do
      let(:condition) { OpenStruct.new(validation_errors: [other_error]) }
      let(:routing_conditions) { [condition] }
      let(:page) { build(:page, id: 2, position: 1, routing_conditions: routing_conditions) }

      it "returns an empty array" do
        expect(step.conditions_with_goto_errors).to be_empty
      end
    end

    context "when routing conditions have mixed errors" do
      let(:condition_mixed) { OpenStruct.new(validation_errors: [cannot_have_goto_page_before_routing_page_error, other_error]) }
      let(:condition_other) { OpenStruct.new(validation_errors: [other_error]) }
      let(:condition_goto) { OpenStruct.new(validation_errors: [goto_page_doesnt_exist_error]) }
      let(:routing_conditions) { [condition_mixed, condition_other, condition_goto] }
      let(:page) { build(:page, id: 2, position: 1, routing_conditions: routing_conditions) }

      it "returns only conditions with specified errors" do
        expect(step.conditions_with_goto_errors).to contain_exactly(condition_mixed, condition_goto)
      end
    end
  end
end
