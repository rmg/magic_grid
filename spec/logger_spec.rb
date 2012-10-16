require 'spec_helper'
require 'magic_grid/logger'

describe MagicGrid do
  it "should user the specified logger" do
    logger = double.tap do |l|
      l.should_receive(:debug)
      l.should_receive(:warn)
      l.should_receive(:error)
    end
    MagicGrid.logger = logger
    MagicGrid.logger.warn "Something is afoot"
    MagicGrid.logger.error "Something is really wrong"
    MagicGrid.logger.debug "Something is foo"
  end
end
