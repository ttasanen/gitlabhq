# == Schema Information
#
# Table name: milestones
#
#  id          :integer          not null, primary key
#  title       :string(255)      not null
#  project_id  :integer          not null
#  description :text
#  due_date    :date
#  created_at  :datetime
#  updated_at  :datetime
#  state       :string(255)
#  iid         :integer
#

require 'spec_helper'

describe Milestone, models: true do
  describe "Associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:issues) }
  end

  describe "Validation" do
    before do
      allow(subject).to receive(:set_iid).and_return(false)
    end

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:project) }
  end

  let(:milestone) { create(:milestone) }
  let(:issue) { create(:issue) }

  describe "unique milestone title per project" do
    it "shouldn't accept the same title in a project twice" do
      new_milestone = Milestone.new(project: milestone.project, title: milestone.title)
      expect(new_milestone).not_to be_valid
    end

    it "should accept the same title in another project" do
      project = build(:project)
      new_milestone = Milestone.new(project: project, title: milestone.title)

      expect(new_milestone).to be_valid
    end
  end

  describe "#percent_complete" do
    it "should not count open issues" do
      milestone.issues << issue
      expect(milestone.percent_complete).to eq(0)
    end

    it "should count closed issues" do
      issue.close
      milestone.issues << issue
      expect(milestone.percent_complete).to eq(100)
    end

    it "should recover from dividing by zero" do
      expect(milestone.issues).to receive(:size).and_return(0)
      expect(milestone.percent_complete).to eq(0)
    end
  end

  describe "#expires_at" do
    it "should be nil when due_date is unset" do
      milestone.update_attributes(due_date: nil)
      expect(milestone.expires_at).to be_nil
    end

    it "should not be nil when due_date is set" do
      milestone.update_attributes(due_date: Date.tomorrow)
      expect(milestone.expires_at).to be_present
    end
  end

  describe :expired? do
    context "expired" do
      before do
        allow(milestone).to receive(:due_date).and_return(Date.today.prev_year)
      end

      it { expect(milestone.expired?).to be_truthy }
    end

    context "not expired" do
      before do
        allow(milestone).to receive(:due_date).and_return(Date.today.next_year)
      end

      it { expect(milestone.expired?).to be_falsey }
    end
  end

  describe :percent_complete do
    before do
      allow(milestone).to receive_messages(
        closed_items_count: 3,
        total_items_count: 4
      )
    end

    it { expect(milestone.percent_complete).to eq(75) }
  end

  describe :items_count do
    before do
      milestone.issues << create(:issue)
      milestone.issues << create(:closed_issue)
      milestone.merge_requests << create(:merge_request)
    end

    it { expect(milestone.closed_items_count).to eq(1) }
    it { expect(milestone.total_items_count).to eq(3) }
    it { expect(milestone.is_empty?).to be_falsey }
  end

  describe :can_be_closed? do
    it { expect(milestone.can_be_closed?).to be_truthy }
  end

  describe :is_empty? do
    before do
      create :closed_issue, milestone: milestone
      create :merge_request, milestone: milestone
    end

    it 'Should return total count of issues and merge requests assigned to milestone' do
      expect(milestone.total_items_count).to eq 2
    end
  end

  describe :can_be_closed? do
    before do
      milestone = create :milestone
      create :closed_issue, milestone: milestone

      create :issue
    end

    it 'should be true if milestone active and all nested issues closed' do
      expect(milestone.can_be_closed?).to be_truthy
    end

    it 'should be false if milestone active and not all nested issues closed' do
      issue.milestone = milestone
      issue.save

      expect(milestone.can_be_closed?).to be_falsey
    end
  end

  describe '#sort_issues' do
    let(:milestone) { create(:milestone) }

    let(:issue1) { create(:issue, milestone: milestone, position: 1) }
    let(:issue2) { create(:issue, milestone: milestone, position: 2) }
    let(:issue3) { create(:issue, milestone: milestone, position: 3) }
    let(:issue4) { create(:issue, position: 42) }

    it 'sorts the given issues' do
      milestone.sort_issues([issue3.id, issue2.id, issue1.id])

      issue1.reload
      issue2.reload
      issue3.reload

      expect(issue1.position).to eq(3)
      expect(issue2.position).to eq(2)
      expect(issue3.position).to eq(1)
    end

    it 'ignores issues not part of the milestone' do
      milestone.sort_issues([issue3.id, issue2.id, issue1.id, issue4.id])

      issue4.reload

      expect(issue4.position).to eq(42)
    end
  end
end
