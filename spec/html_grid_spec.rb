require 'spec_helper'
require 'magic_grid/html_grid'
require 'magic_grid/definition'

describe MagicGrid::HtmlGrid do

  let(:empty_collection) { [] }
  let(:column_list) { [:name, :description] }
  let(:controller) { make_controller }
  # Kaminari uses view_renderer instead of controller
  let(:view_renderer) { controller }

  describe "#grid_row" do
    let(:tracer) { "OMG A MAGIC CELL!" }

    context "with a callable column option" do
      let(:record) { 1 }

      it "should use :to_s as a method if callable" do
        callable = double.tap do |c|
          c.should_receive(:call).with( record ) { tracer }
        end
        cols = [ {col: 'Col', to_s: callable} ]
        grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
        grid.grid_row( record ).should include(tracer)
      end

      it "should use :col as a method if callable" do
        callable = double.tap do |c|
          c.should_receive(:call).with( record ) { tracer }
        end
        cols = [ {col: callable, label: "Column"} ]
        grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
        grid.grid_row( record ).should include(tracer)
      end
    end

    context "with a symbol that is a method on the record" do
      let(:record) { double(1) }

      it "should use :to_s as a method on record if it responds to it" do
        record.should_receive(:some_inconceivable_method_name) { tracer }
        cols = [ {col: :some_col, to_s: :some_inconceivable_method_name} ]
        grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
        grid.grid_row( record ).should include(tracer)
      end

      it "should use :col as a method on record if it responds to it" do
        record.should_receive(:some_inconceivable_method_name) { tracer }
        cols = [ {col: :some_inconceivable_method_name} ]
        grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
        grid.grid_row( record ).should include(tracer)
      end
    end
  end

  describe "#magic_column_headers" do
    it "should allow a string as a column definition" do
      title = "A String"
      cols = [title]
      grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
      grid.magic_column_headers.should include(title)
    end
    it "should use :label if no :sql is given" do
      title = "A String"
      cols = [{label: title}]
      grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
      grid.magic_column_headers.should include(title)
    end
    it "should make a sortable header if :sql is specified" do
      tracer = "A MAGIC BULL??"
      col = {sql: 'some_col'}
      cols = [col]
      grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols), self
      # TODO: check parameters to sortable_header
      #self.should_receive(:sortable_header).with(grid, col, {}) { tracer }
      grid.should_receive(:sortable_header) { tracer }
      grid.magic_column_headers.should include(tracer)
    end
  end

  describe "#searcher_input" do
    searchable_opts = { needs_searcher: true }
    it "renders a search field" do
      cols = [:some_col]
      grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols, nil, nil, searchable_opts), self
      grid.searcher_input.should match_select("input[type=search]")
    end
    it "renders a search button if told to" do
      tracer = "ZOMG! A BUTTON!"
      cols = [:some_col]
      opts = searchable_opts.merge(search_button: true,
                                   searcher_button: tracer)
      grid = MagicGrid::HtmlGrid.new MagicGrid::Definition.new(cols, nil, nil, opts), self
      grid.searcher_input.should match_select("button", text: tracer)
    end
  end

  describe "column sorting helpers" do
    subject { MagicGrid::HtmlGrid.new nil, self }
    it "#reverse_order" do
      subject.reverse_order(0).should == 1
      subject.reverse_order(1).should == 0
      subject.reverse_order(2).should == 0
    end
    it "#order_icon" do
      subject.order_icon(0).should match_select('span.ui-icon-triangle-1-n')
      subject.order_icon(1).should match_select('span.ui-icon-triangle-1-s')
      subject.order_icon(2).should match_select('span.ui-icon-carat-2-n-s')
    end
    it "#order_class" do
      subject.order_class(0).should == 'sort-asc'
      subject.order_class(1).should == 'sort-desc'
      subject.order_class(2).should == 'sort-none'
    end
  end
end
