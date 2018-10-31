module Spree::QbdIntegration::Action
  extend ActiveSupport::Concern
  include Spree::QbdIntegration::Helper
  include Spree::QbdIntegration::Action::Address
  include Spree::QbdIntegration::Action::Account
  include Spree::QbdIntegration::Action::CustomerType
  include Spree::QbdIntegration::Action::LineItem
  include Spree::QbdIntegration::Action::Order
  include Spree::QbdIntegration::Action::PaymentTerm
  include Spree::QbdIntegration::Action::Rep
  include Spree::QbdIntegration::Action::StockLocation
  include Spree::QbdIntegration::Action::StockTransfer
  include Spree::QbdIntegration::Action::TaxCategory
  include Spree::QbdIntegration::Action::ShippingMethod
  include Spree::QbdIntegration::Action::TaxRate
  include Spree::QbdIntegration::Action::Variant
  include Spree::QbdIntegration::Action::ChartAccount
  include Spree::QbdIntegration::Action::PaymentMethod
  include Spree::QbdIntegration::Action::CreditMemo
  include Spree::QbdIntegration::Action::Payment
  include Spree::QbdIntegration::Action::AccountPayment
  include Spree::QbdIntegration::Action::TxnClass
  include Spree::QbdIntegration::Action::Vendor
  include Spree::QbdIntegration::Action::Fetch::Account
  include Spree::QbdIntegration::Action::Fetch::ChartAccount
  include Spree::QbdIntegration::Action::Fetch::Variant
  include Spree::QbdIntegration::Action::Fetch::Order
  include Spree::QbdIntegration::Action::Fetch::CreditMemo
  include Spree::QbdIntegration::Action::Fetch::AccountPayment

  attr_accessor :qbd_response_xml

  def qbd_trigger(integrationable_id, integrationable_type, integration_action)
    if integrationable_id.nil? && self.sync_id.present?
      case integrationable_type
      when 'Spree::Variant'
        self.qbd_pull_variant
      when 'Spree::Account'
        self.qbd_pull_account
      when 'Spree::Order'
        self.qbd_pull_order
      when 'Spree::CreditMemo'
        self.qbd_pull_credit_memo
      when 'Spree::AccountPayment'
        self.qbd_pull_account_payment
      else
        { status: -1, log: 'Not yet implemented'}
      end
    elsif integrationable_id.nil? && self.sync_id.blank?
      case integrationable_type
      when 'Spree::Variant'
        self.qbd_get_variants(integration_action)
      when 'Spree::Account'
        self.qbd_get_accounts(integration_action)
      when 'Spree::Order'
        self.qbd_get_orders(integration_action)
      when 'Spree::CreditMemo'
        self.qbd_get_credit_memos(integration_action)
      when 'Spree::AccountPayment'
        self.qbd_get_account_payments(integration_action)
      else
        { status: -1, log: 'Not yet implemented'}
      end
    else
      case integrationable_type
      when 'Spree::Order'
        self.qbd_synchronize_order(integrationable_id, integration_action)
      when 'Spree::Account'
        self.qbd_synchronize_account(integrationable_id, integration_action)
      when 'Spree::Variant'
        self.qbd_synchronize_variant(integrationable_id, integration_action)
      when 'Spree::StockTransfer'
        self.qbd_synchronize_stock_transfer(integrationable_id, integration_action)
      when 'Spree::Payment'
        self.qbd_synchronize_payment(integrationable_id, integration_action)
      when 'Spree::CreditMemo'
        self.qbd_synchronize_credit_memo(integrationable_id, integration_action)
      when 'Spree::AccountPayment'
        self.qbd_synchronize_account_payment(integrationable_id, integration_action)
      else
        { status: -1, log: 'Unknown Integrationable Type' }
      end
    end
  end

  def qbd_synchronize_order(order_id, integration_action)
    order = Spree::Order.find_by_id(order_id)
    if order.try(:has_unsynced_inventory_items?, self.integration_item.integration_key)
      { status: -1, log: 'This order contains inventory items that were not previously synced. Manual adjustments to your Quickbooks Inventory will be needed after syncing this order.'}
    else
      { status: 0, log: 'Enqueued' }
    end
  end

  def qbd_synchronize_credit_memo(credit_memo_id, integration_action)
    { status: 0, log: 'Enqueued' }
  end

  def qbd_synchronize_account(account_id, integration_action)
    { status: 0, log: 'Enqueued' }
  end

  def qbd_synchronize_variant(variant_id, integration_action)
    { status: 0, log: 'Enqueued' }
  end

  def qbd_synchronize_stock_transfer(stock_transfer_id, integration_action)
    if self.integration_item.qbd_track_inventory
      { status: 0, log: 'Enqueued' }
    else
      integration_action.destroy!
    end
  end

  def qbd_synchronize_payment(payment_id, integration_action)
    {status: 0, log: 'Enqueued'}
  end

  def qbd_synchronize_account_payment(payment_id, integration_action)
    {status: 0, log: 'Enqueued'}
  end

  # Qbd sync methods

  def qbd_unknown_step_method
    raise "Unknown Qbd Handler Method"
  end

  # Returns the request XML from the payload.
  def qbd_build
    self.reload
    if step.blank?
      begin
        if self.sync_id.present?
          self.step = self.method(self.qbd_pull_step_method).call.as_json
        elsif self.integrationable_id.nil?
          self.step = self.method(self.qbd_get_step_method).call.as_json
        else
          self.step = self.method(self.qbd_step_method).call(self.integrationable_id).as_json
        end
        self.save
      rescue Exception => e
        self.update_attributes({ status: -1, execution_log: e.message })
        return ''
      end

      # self.integration_steps.create(
      #   sync_id: self.sync_id,
      #   sync_type: self.sync_type,
      #   integrationable_type: self.integrationable_type,
      #   details: self.step
      # ).make_current
    end

    puts "qbd_build STEP:"
    puts "----- #{step.to_json}"
    puts ""
    if current_step
      puts "Current Step"
      puts "id: #{current_step.id}"
      puts "parent_id: #{current_step.parent_id}"
      puts "details: #{current_step.details}"
    else
      puts "NO CURRENT STEP"
    end
    begin
      if self.integration_item.last_action == step.to_json
        self.update_attributes({status: -1, execution_log: 'Infinite loop detected. Interupting...'})
        self.integration_item.update_attributes({last_action: step.to_json, last_error: 'Infinite loop detected. Interupting...'})
        return ""
      end
      self.integration_item.update_attributes({last_action: step.to_json})
      self.qbd_request_method
    rescue Exception => e
      self.update_attributes({ status: -1, execution_log: "An error occurred building XML in #{step.fetch('step_type','')} step for #{step.fetch('object_class','')} with id #{step.fetch('object_id','')}. #{e.class.to_s} - #{e.message}" })
    end
  end

  # Attempts to perform the work represented by this job instance.
  # Calls #perform on the class given in the payload with the
  # Quickbooks response and the arguments given in the payload..
  def qbd_handle(response_xml)
    self.touch(:last_response_time)
    self.reload
    if step.blank?
      begin
        if self.sync_id.present?
          self.step = self.method(self.qbd_pull_step_method).call.as_json
        elsif self.integrationable_id.nil?
          self.step = self.method(self.qbd_get_step_method).call.as_json
        else
          self.step = self.method(self.qbd_step_method).call(self.integrationable_id).as_json
        end
        self.save
      rescue Exception => e
        self.update_attributes({ status: -1, execution_log: e.message })
        return ''
      end
    end

    self.update_attributes({prev_step: step})
    qbd_create_step(self.step).try(:make_current) unless current_step.present?
    self.reload

    puts "qbd_handle STEP:"
    puts "----- #{step.to_json}"
    puts ""
    if current_step
      puts "Current Step"
      puts "id: #{current_step.id}"
      puts "parent_id: #{current_step.parent_id}"
      puts "details: #{current_step.details}"
    else
      puts "NO CURRENT STEP"
    end
    begin
      self.qbd_handler_method(response_xml)
    rescue Exception => e
      self.integration_item.update_attributes({
        last_action: "",
        last_error: "An error occurred handling response from Quickbooks.\n#{e.class.to_s} - #{e.message}"
      })
      self.update_attributes({
        execution_count: self.execution_count.to_i + 1,
        status: -1,
        execution_log: "An error occurred handling response from Quickbooks.\n#{e.class.to_s} - #{e.message}"
      })
    ensure
      self.update_columns(processed_at: Time.current)
    end
  end

  def qbd_step_method
    "qbd_#{self.integrationable_type.demodulize.underscore}_step" rescue 'qbd_unknown_builder_method'
  end

  def qbd_get_step_method
    "qbd_#{self.integrationable_type.demodulize.underscore}_get_step" rescue 'qbd_unknown_builder_method'
  end

  def qbd_pull_step_method
    "qbd_#{self.integrationable_type.demodulize.underscore}_pull_step" rescue 'qbd_unknown_builder_method'
  end

  #
  #
  # Universal Request Handler method
  #
  #
  def qbd_request_method
    unless step.fetch('iterator', nil) || step.fetch('object_id', nil).blank?
      if step.fetch('object_class').starts_with?('Spree::StockTransfer')
        # StockTransfers use multiple object classes to designate between transfer, adjustments, and assembly builds
        object = Spree::StockTransfer.find(step.fetch('object_id'))
        object_hash = object.to_integration(
          self.integration_item.integrationable_options_for(object)
        )
      elsif step.fetch('object_id', nil)
        object = step.fetch('object_class').constantize.find(step.fetch('object_id'))
        object_hash = object.to_integration(
          self.integration_item.integrationable_options_for(object)
        )
      else
        object_hash = {}
      end
    end
    builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII")
    case step.fetch('step_type')
    # when :terminate, 'terminate'
    #   self.status = 5
    #   self.execution_log = object_hash.fetch(:name_for_integration)
    #   self.execution_count += 1
    #   self.save
    #   return ""
    when :query, 'query', :terminate, 'terminate'
      unless step.fetch('iterator', nil)
        if step.fetch('qbxml_query_by', nil) == 'ListID' && step.fetch('sync_id', nil).present?
          query_by = step.fetch('sync_id')
        else
          query_by = case step.fetch('object_class')
          when 'Spree::Variant', 'Spree::Product'
            self.integration_item.qbd_match_with_name ? object_hash.fetch(:fully_qualified_name, nil) : object_hash.fetch(:fully_qualified_sku, nil)
          when 'Spree::Payment', 'Spree::AccountPayment'
            if step.fetch('qbxml_query_by', nil) == 'TxnID'
              self.integration_item.integration_sync_matches.where(
                integration_syncable_type: step.fetch('object_class'),
                integration_syncable_id: object_hash.fetch(:id)
              ).first.try(:sync_id)
            else
              qbd_payment_ref_number(object_hash)
            end
          when 'Spree::Rep'
            step.fetch('sync_type') == 'SalesRep' ? object_hash.fetch(:initials) : object_hash.fetch(:fully_qualified_name)
          else
            object_hash.fetch(:fully_qualified_name)
          end
        end
      end
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            if step.fetch('iterator', nil)
              xml.send("#{step.fetch('qbxml_class')}QueryRq", iterator: "#{step.fetch('iterator')}", iteratorID: "#{step.fetch('iterator_id', nil)}") do
                xml.MaxReturned 20
                # xml.IncludeRetElement 'ListID'
                # xml.IncludeRetElement 'FullName'
                if self.integration_item.last_pulled_at(step.fetch('object_class')).present?
                  self.method("qbd_#{step.fetch('object_class').demodulize.underscore}_modified_range_xml").call(xml)
                end
              end
            else
              xml.send("#{step.fetch('qbxml_class')}QueryRq") do
                xml.send(step.fetch('qbxml_query_by'), query_by)
              end
            end
          end
        end
      end
    when :create, 'create'
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            xml.send("#{step.fetch('qbxml_class')}AddRq") do
              xml.send("#{step.fetch('qbxml_class')}Add") do
                self.method("qbd_#{step.fetch('object_class').demodulize.underscore}_to_#{step.fetch('qbxml_class').underscore}_xml").call(xml, object_hash, nil)
              end
            end
          end
        end
      end
    when :push, 'push'
      if step.fetch('sync_type', nil)
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'), sync_type: step.fetch('sync_type'))
      else
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
      end
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            xml.send("#{step.fetch('qbxml_class')}ModRq") do
              xml.send("#{step.fetch('qbxml_class')}Mod") do
                self.method("qbd_#{step.fetch('object_class').demodulize.underscore}_to_#{step.fetch('qbxml_class').underscore}_xml").call(xml, object_hash, match)
              end
            end
          end
        end
      end
    when :pull, 'pull'
      # if self.current_step.present? && self.current_step.details.fetch('qbxml_query_by', nil) == 'ListID'
      if step.fetch('qbxml_query_by', nil) == 'ListID' || step.fetch('qbxml_query_by', nil) == 'TxnID'
        query_by = step.fetch('sync_id')
      else
        if step.fetch('sync_type', nil)
          match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'), sync_type: step.fetch('sync_type'))
        else
          match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
        end
        query_by = match.sync_id
      end
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            xml.send("#{step.fetch('qbxml_class')}QueryRq") do
              xml.send(step.fetch('qbxml_match_by'), query_by)
              if self.respond_to? "qbd_#{step.fetch('qbxml_class').underscore}_query_xml".to_sym
                self.method("qbd_#{step.fetch('qbxml_class').underscore}_query_xml").call(xml)
              end
            end
          end
        end
      end
    when :void, 'void'
      if step.fetch('sync_type', nil)
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'), sync_type: step.fetch('sync_type'))
      else
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
      end
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            xml.TxnVoidRq do
              self.method("qbd_#{step.fetch('object_class').demodulize.underscore}_to_void_#{step.fetch('qbxml_class').underscore}_xml").call(xml, object_hash, match)
            end
          end
        end
      end
    when :delete, 'delete'
      if step.fetch('sync_type', nil)
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'), sync_type: step.fetch('sync_type'))
      else
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
      end
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            xml.TxnDelRq do
              self.method("qbd_#{step.fetch('object_class').demodulize.underscore}_to_delete_#{step.fetch('qbxml_class').underscore}_xml").call(xml, object_hash, match)
            end
          end
        end
      end
    when :filter, 'filter'
      if step.fetch('sync_type', nil)
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'), sync_type: step.fetch('sync_type'))
      else
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
      end
      builder = Nokogiri::XML::Builder.new(encoding: "US-ASCII") do |xml|
        xml.QBXML do
          xml.QBXMLMsgsRq(onError: 'stopOnError') do
            xml.send("#{step.fetch('qbxml_class')}QueryRq") do
              self.method("qbd_#{step.fetch('object_class').demodulize.underscore}_to_#{step.fetch('qbxml_class').underscore}_xml").call(xml, object_hash, match)
            end
          end
        end
      end
    end

    info = Nokogiri::XML::ProcessingInstruction.new(builder.doc, 'qbxml', 'version="13.0"')
    builder.doc.root.add_previous_sibling info
    builder.to_xml
  end

  #
  # Universal Response Handler method
  #
  def qbd_handler_method(response_xml)
    unless step.fetch('iterator', nil) || step.fetch('object_id', nil).blank?
      if step.fetch('object_class').starts_with?('Spree::StockTransfer')
        # StockTransfers use multiple object classes to designate between transfer, adjustments, and assembly builds
        object = Spree::StockTransfer.find(step.fetch('object_id'))
        object_hash = object.to_integration(
          self.integration_item.integrationable_options_for(object)
        )
      else
        object = step.fetch('object_class').constantize.find(step.fetch('object_id'))
        object_hash = object.to_integration(
          self.integration_item.integrationable_options_for(object)
        )
      end
    end
    puts "response_xml"
    puts "#{response_xml}"

    # Handle parsing error.
    if response_xml.blank?
      self.status = -1
      self.execution_log = 'Parsing Error.'
      self.save
      return
    end
    unless step.fetch('iterator', nil) || step.fetch('object_id', nil).blank?
      if step.fetch('sync_type', nil)
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'), sync_type: step.fetch('sync_type'))
      else
        match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
      end
    end
    response = Nokogiri.XML(response_xml)
    qbxml_class = step.fetch('qbxml_class', '')
    case step.fetch('step_type')
    when :terminate, 'terminate'
      # response_status[:status] = 5 # we are done with this step
      response_status = {status: 5, execution_log: ''}
      self.current_step.try(:update, {status: 10})
      self.update_attributes(response_status)
    when :query, 'query'
      response_status = self.qbd_response_status(response_xml, "#{qbxml_class}QueryRs")
      if step.fetch('iterator', nil)
        #create new jobs
        list = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_class}QueryRs/#{qbxml_class}Ret")
        if self.integration_item.try(:qbd_export_list_to_csv)
          qbd_export_list_to_csv(list, qbxml_class)
        else
        # list = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_match_by')}")
          list.each_with_index do |object, idx|
            object_hash = Hash.from_xml(object.to_xml).fetch("#{qbxml_class}Ret", {})
            puts "CREATE JOB #{idx + 1}"
            create_new_job(step.fetch('object_class'), object_hash, qbxml_class)
          end
        end
        remaining_object_count = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_class}QueryRs").attr('iteratorRemainingCount').try(:value).to_i
        if remaining_object_count > 0
          response_status[:status] = 1
          step['iterator'] = 'Continue'
          step['iterator_id'] = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_class}QueryRs").attr('iteratorID').try(:value)
          step['iterator_remaining_count'] = remaining_object_count
          self.save
        else
          self.current_step.try(:update, {status: 10})
          self.update_attributes({step: {}})
        end
        self.update_attributes(response_status)
      else
        if response_status.fetch(:status) == 2
          self.update_attributes(response_status)
        elsif response_status.fetch(:status) == -2 #query not found in QBD
          if self.integration_item.qbd_should_create_object(step.fetch('object_class'))
            self.current_step.try(:update, {status: 10})
            match.sync_id = ""
            match.save
            qbd_create_step(
              self.method(
                "qbd_#{match.integration_syncable_type.demodulize.underscore}_step"
              ).call(match.integration_syncable_id, current_step.try(:parent_id)),
              current_step.try(:parent_id)
            )
          else
            response_status[:status] = 2 # set status Failing before we move forward
            self.update_attributes(response_status)
          end
        elsif response_status.fetch(:status) == 5
          match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_class}QueryRs/#{qbxml_class}Ret/#{step.fetch('qbxml_match_by')}").try(:children).try(:text)
          match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_class}QueryRs/#{qbxml_class}Ret/EditSequence").try(:children).try(:text)
          match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
          match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
          match.sync_type = step.fetch('qbxml_class')
          match.save
          self.match_related(response, "#{step.fetch('qbxml_class')}QueryRs")
          if step.fetch('next_step', 'continue') == 'skip' || self.integration_item.qbd_overwrite_conflicts_in == 'none'
            response_status[:status] = 5 # set status Processed before we move forwrad so we DONT push/pull afterwards
            self.current_step.try(:update, {status: 10})
          else
            response_status[:status] = 1 # set status Processing before we move forwrad so we push/pull afterwards
            self.current_step.try(:update, {status: 10}) unless self.current_step.try(:sub_steps).present?
            qbd_create_step(
              self.method(
                "qbd_#{match.integration_syncable_type.demodulize.underscore}_step"
              ).call(match.integration_syncable_id, current_step.try(:parent_id)),
              current_step.try(:parent_id)
            )
          end
          self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
        end
        self.update_attributes({step: {}})
      end
    when :create, 'create'
      response_status = self.qbd_response_status(response_xml, "#{step.fetch('qbxml_class')}AddRs")
      if response_status.fetch(:status) == 2
        self.update_attributes(response_status)
      elsif response_status.fetch(:status) == 5
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}AddRs/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_match_by')}").try(:children).try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}AddRs/#{step.fetch('qbxml_class')}Ret/EditSequence").try(:children).try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.match_related(response, "#{step.fetch('qbxml_class')}AddRs")
        if self.current_step && self.current_step.sub_steps.incomplete.blank?
          self.current_step.try(:update, {status: 10})
        end
        # if step.fetch('next_step', 'skip').to_s == 'continue'
        #   response_status[:status] = 1 # set status Processing before we move forwrad so we continue with same IntegrationAction
        # end
        self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
      end
      self.update_attributes({step: {}})
    when :push, 'push'
      response_status = self.qbd_response_status(response_xml, "#{step.fetch('qbxml_class')}ModRs")
      if response_status.fetch(:status) == 2
        self.update_attributes(response_status)
      elsif response_status.fetch(:status) == -3
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}ModRs/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_match_by')}").try(:children).try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}ModRs/#{step.fetch('qbxml_class')}Ret/EditSequence").try(:children).try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.integration_item.update_attributes({last_action: {}})
      elsif response_status.fetch(:status) == 5
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}ModRs/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_match_by')}").try(:children).try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}ModRs/#{step.fetch('qbxml_class')}Ret/EditSequence").try(:children).try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.match_related(response, "#{step.fetch('qbxml_class')}ModRs")
        if self.current_step && self.current_step.sub_steps.incomplete.blank?
          self.current_step.try(:update, {status: 10})
        end
        self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
      end
      self.update_attributes({step: {}})
    when :pull, 'pull'
      response_status = self.qbd_response_status(response_xml, "#{qbxml_class}QueryRs")
      if step.fetch('object_id', nil).nil?
        qbd_object = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_class}QueryRs/#{qbxml_class}Ret")
        qbd_object_hash = Hash.from_xml(qbd_object.to_xml).fetch("#{qbxml_class}Ret", {})
        puts "START CREATE OBJECT"
        create_new_object(qbd_object_hash, qbxml_class, step.fetch('object_class'))
        if self.current_step && self.current_step.sub_steps.incomplete.blank?
          self.update_attributes(response_status)
          self.current_step.try(:update, {status: 10})
        end
      else
        if response_status.fetch(:status) == 2
          self.update_attributes(response_status)
        elsif response_status.fetch(:status) == 5
          if self.method("qbd_all_associated_matched_#{step.fetch('qbxml_class').underscore}?").call(response, object_hash)
            match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_match_by')}").try(:children).try(:text)
            match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/EditSequence").try(:children).try(:text)
            match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
            match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
            match.sync_type = step.fetch('qbxml_class')
            match.no_sync = true
            match.save
            self.match_related(response, "#{step.fetch('qbxml_class')}QueryRs")
            step.fetch('object_class').constantize.find(step.fetch('object_id')).from_integration(self.method("qbd_#{step.fetch('qbxml_class').underscore}_xml_to_#{step.fetch('object_class').demodulize.underscore}").call(response, object_hash))
            self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
            self.current_step.try(:update, {status: 10})
          end
        end
      end
    when :void, 'void'
      response_status = self.qbd_response_status(response_xml, "TxnVoidRs")
      if response_status.fetch(:status) == 2
        self.update_attributes(response_status)
      elsif response_status.fetch(:status) == -3
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnVoidRs/#{step.fetch('qbxml_match_by')}").try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnVoidRs/EditSequence").try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.integration_item.update_attributes({last_action: {}})
      elsif response_status.fetch(:status) == 5
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnVoidRs/#{step.fetch('qbxml_match_by')}").try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnVoidRs/EditSequence").try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
      end
      self.update_attributes({step: {}})
    when :delete, 'delete'
      response_status = self.qbd_response_status(response_xml, "TxnDelRs")
      if response_status.fetch(:status) == 2
        self.update_attributes(response_status)
      elsif response_status.fetch(:status) == -3
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnDelRs/#{step.fetch('qbxml_match_by')}").try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnDelRs/EditSequence").try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.integration_item.update_attributes({last_action: {}})
      elsif response_status.fetch(:status) == 5
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnDelRs/#{step.fetch('qbxml_match_by')}").try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/TxnDelRs/EditSequence").try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
      end
      self.update_attributes({step: {}})
    when :filter, 'filter'
      response_status = self.qbd_response_status(response_xml, "#{step.fetch('qbxml_class')}QueryRs")
      if response_status.fetch(:status) == 2
        self.update_attributes(response_status)
      elsif response_status.fetch(:status) == 5
        match.sync_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_match_by')}").try(:children).try(:text)
        match.sync_alt_id = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/EditSequence").try(:children).try(:text)
        match.sync_object_created_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeCreated").try(:children).try(:text)
        match.sync_object_updated_at = response.xpath("//QBXML/QBXMLMsgsRs/#{step.fetch('qbxml_class')}QueryRs/#{step.fetch('qbxml_class')}Ret/TimeModified").try(:children).try(:text)
        match.sync_type = step.fetch('qbxml_class')
        match.save
        self.method("qbd_#{step.fetch('qbxml_class').underscore}_xml_to_#{step.fetch('object_class').demodulize.underscore}").call(response, object_hash)
        self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
      elsif response_status.fetch(:status) == -2
        puts match.save
        response_status[:status] = 2
        self.update_attributes(response_status) if self.integrationable_id == match.integration_syncable_id && self.integrationable_type == match.integration_syncable_type
      end
      self.update_attributes({step: {}})
    end

    puts "Response Status: #{response_status.fetch(:status, '')}"
    # return if response_status.fetch(:status, '') == 2 #2 is Failed status

    next_step = self.next_integration_step
    if current_step.try(:details).try(:fetch, 'iterator', nil).present? && next_step.nil? && !self.integration_item.try(:qbd_export_list_to_csv)
      object_class = current_step.details.fetch('object_class', '')
      self.integration_item.send("touch_#{object_class.to_s.demodulize.underscore}_last_pulled_at")
      self.integration_item.save
      self.update_columns(execution_log: "#{object_class.demodulize.titleize} Enqueuing Complete")
    end
    if next_step && next_step.id != current_step.try(:id)
      next_step.make_current
      self.step = next_step.details
      self.status = 1 if response_status[:status] == 5

      self.save
    elsif current_step.try(:details).try(:fetch, 'run_callbacks', false) && self.integrationable_type == current_step.integrationable_type
      callback_method = "qbd_create_#{current_step.details.fetch('object_class', '').to_s.demodulize.underscore}_callback_steps".to_sym
      if self.respond_to? callback_method
        self.method(callback_method).call(current_step.details.fetch('object_id'))
      end
      # TODO handle callback steps
      # next_step = self.next_integration_step
      # if next_step && next_step.id != current_step.try(:id)
      #   next_step.make_current
      #   self.step = next_step.details
      #   self.status = 1 if response_status[:status] == 5
      #
      #   self.save
      # end
      self.integration_steps.update_all(is_current: false) if self.step.blank?
    else
      self.integration_steps.update_all(is_current: false) if self.step.blank?
    end
    self.reload
  end

  def create_new_object(qbd_hash, qbxml_class, object_class)
    new_object_method = "qbd_#{qbxml_class.underscore}_create_#{object_class.demodulize.underscore}_sub_steps"
    unless self.respond_to? new_object_method
      new_object_method = "qbd_#{qbxml_class.underscore}_hash_to_#{object_class.demodulize.underscore}"
    end

    self.method(new_object_method).call(qbd_hash)
  end

  def qbd_export_list_to_csv(list, qbxml_class)
    file_name = "#{self.company.name.parameterize.underscore}_items_#{Date.current.to_s.underscore}.csv"
    file_path = "#{Rails.root.join('tmp', file_name)}"
    headers = qbd_item_csv_headers
    item_file = CSV.open(file_path, 'a+') do |csv|
      csv << headers if csv.count.zero?
      list.each_with_index do |object, idx|

        object_hash = Hash.from_xml(object.to_xml).fetch("#{qbxml_class}Ret", {})
        self.method("qbd_#{qbxml_class.underscore}_to_csv").call(csv, object_hash)
      end
    end

    s3 = Aws::S3::Resource.new(
      region:'us-east-1',
      credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY'], ENV['S3_SECRET'])
    )
    obj = s3.bucket(ENV['S3_FILESHARE_BUCKET']).object(file_name)
    obj.upload_file(file_path)
  end

  def create_new_job(object_class, object_hash, qbxml_class)
    case object_class
    when 'Spree::Order', 'Spree::Payment', 'Spree::AccountPayment', 'Spree::CreditMemo'
      sync_id = object_hash.fetch('TxnID', nil)
      full_name = object_hash.fetch('RefNumber', nil)
    else
      sync_id = object_hash.fetch('ListID', nil)
      full_name = object_hash.fetch('FullName', nil) || object_hash.fetch('Name', nil)
    end
    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: object_class,
      sync_id: sync_id
    ).where.not(integration_syncable_id: nil).first
    if match #&& self.integration_item.can_create_job_for?(object_class)
      # comment out to skip if exists
      unless self.integration_item.try(:skip_updates_from_integration, object_class) \
        || match.sync_object_is_unchanged?(object_hash.fetch('TimeModified', nil))
        match.integration_item.integration_actions.create(
          integrationable_id: match.integration_syncable_id,
          integrationable_type: match.integration_syncable_type
        )
      end
    else
      object = self.method("qbd_#{object_class.demodulize.underscore}_find_by_name").call(full_name)

      if object
        match = self.integration_item.integration_sync_matches.create!(
          integration_syncable_type: object_class,
          sync_id: sync_id,
          integration_syncable_id: object.id
        )
        # comment out to skip if exists
        unless self.integration_item.try(:skip_updates_from_integration, object_class)
          match.integration_item.integration_actions.create(
            integrationable_id: match.integration_syncable_id,
            integrationable_type: match.integration_syncable_type
          )
        end
      else
        return if object_hash.key?('IsActive') && !object_hash.fetch('IsActive')
        self.method("qbd_#{object_class.demodulize.underscore}_create").call(object_hash, qbxml_class)
        # create job to find and create
      end
    end
  end

  def match_related(response, qbxml_element)
    if step.fetch('object_class') == 'Spree::Order' && step.fetch('object_id', nil)
      order_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: step.fetch('object_id'), integration_syncable_type: step.fetch('object_class'))
      order = order_match.integration_syncable
      response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_class')}LineRet").each do |item|
        item_ref_list_id = item.xpath('ItemRef/ListID').try(:text)
        item_ref_match = self.integration_item.integration_sync_matches.where(sync_id: item_ref_list_id).first
        if item_ref_match.try(:integration_syncable_type) == 'Spree::Variant'
          line_item = order.line_items.where(variant_id: item_ref_match.integration_syncable_id).first
          if line_item
            line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.id, integration_syncable_type: line_item.class.name)
            line_item_match.sync_id = item.xpath('TxnLineID').try(:text)
            line_item_match.sync_type = step.fetch('qbxml_class')
            line_item_match.save
          end
        end
      end
      response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/#{step.fetch('qbxml_class')}Ret/#{step.fetch('qbxml_class')}LineGroupRet").each do |group_item|
        item_ref_list_id = group_item.xpath('ItemGroupRef/ListID').try(:text)
        item_ref_match = self.integration_item.integration_sync_matches.where(sync_id: item_ref_list_id).first
        if item_ref_match.try(:integration_syncable_type) == 'Spree::Variant'
          line_item = order.line_items.where(variant_id: item_ref_match.integration_syncable_id).first
          if line_item
            line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.id, integration_syncable_type: line_item.class.name)
            line_item_match.sync_id = group_item.xpath('TxnLineID').try(:text)
            line_item_match.sync_type = step.fetch('qbxml_class')
            line_item_match.save
          end
        end
      end
    elsif step.fetch('object_class') == 'Spree::Variant'
      # response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/#{step.fetch('qbxml_class')}Ret/")

    end
  end

  #
  # Response Status
  #
  def qbd_response_status(response_xml, qbxml_element)
    response = Nokogiri.XML(response_xml)
    statusCode = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/@statusCode").try(:first).try(:value)
    statusMessage = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/@statusMessage").try(:first).try(:value)
    iteratorID = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/@iteratorID").try(:first).try(:value)
    iteratorRemainingCount = response.xpath("//QBXML/QBXMLMsgsRs/#{qbxml_element}/@iteratorRemainingCount").try(:first).try(:value)

    case statusCode
    when '0'
      # OK
      { status: 5, execution_log: "#{qbxml_element} -- #{statusMessage}", execution_count: self.execution_count + 1 }
    when '1'
      if iteratorID.present? && iteratorRemainingCount == '0'
        { status: 5, execution_log: "#{qbxml_element} -- #{statusMessage}", execution_count: self.execution_count + 1 }
      else
        # Unable to find match (for Tax Rate/)
        { status: -2, execution_log: "#{qbxml_element} -- #{statusMessage}", execution_count: self.execution_count + 1 }
      end
    when '500'
      # Unable to find match
      { status: -2, execution_log: "#{qbxml_element} -- #{statusMessage}", execution_count: self.execution_count + 1 }
    when '3170'
      if statusMessage.to_s.include?("Cannot use SalesAndPurchaseMod aggregate when the item is not reimbursable")
        statusMessage = "Quickbooks SDK does not support changing from only 'for sale'
          or 'for purchase' to both 'for sale and purchase'. Please select 'This item is
          used in assemblies or is purchased for a specific customer job' within Quickbooks
          UI and restart this job."
      end
      {
        status: 2,
        execution_log: "#{qbxml_element} -- #{statusMessage}",
        execution_count: self.execution_count + 1
      }
    when '3200'
      # EditSequence out of date
      # automatically retry again
      { status: -3, execution_log: "#{qbxml_element} -- #{statusMessage}", execution_count: self.execution_count + 1 }
    when '3250'
      {
        status: 2,
        execution_log: "#{qbxml_element} -- #{statusMessage} #{I18n.t('integrations.qbd.feature_unavailable')}",
        execution_count: self.execution_count + 1
      }
    else
      # Unrecognized Status Code
      { status: 2, execution_log: "#{qbxml_element} -- #{statusMessage}", execution_count: self.execution_count + 1 }
    end
  end

  def qbd_create_or_update_match(syncable_object, syncable_type, integration_sync_id, sync_type, sync_object_created_at, sync_object_updated_at, sync_alt_id = nil)
    return if syncable_object.try(:id).nil?

    match = self.integration_item.integration_sync_matches.find_by(
      integration_syncable_type: syncable_type,
      integration_syncable_id: syncable_object.id
    )

    match ||= self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: syncable_type,
      sync_type: sync_type,
      sync_id: integration_sync_id
    )

    if current_step
      current_step.integration_syncable_id = syncable_object.id
      current_step.details.merge!({'object_id' => syncable_object.id })
      current_step.save
    end

    match.integration_syncable_id = syncable_object.id
    match.sync_id = integration_sync_id
    match.sync_alt_id = sync_alt_id if sync_alt_id.present?
    match.sync_object_created_at = sync_object_created_at if sync_object_created_at
    match.sync_object_updated_at = sync_object_updated_at if sync_object_updated_at

    match.no_sync = true
    match.save

    if (self.integrationable_id.nil? && self.sync_id.present? &&
        integrationable_type == syncable_type && match.sync_id == self.sync_id)

      self.update_columns(integrationable_id: syncable_object.id)
    end

  end

  def qbd_find_or_build_match(syncable_object, syncable_type, sync_id, sync_type, sync_object_created_at, sync_object_updated_at, sync_alt_id = nil)
    match = self.integration_item.integration_sync_matches.find_by(
      integration_syncable_type: syncable_type,
      integration_syncable_id: syncable_object.id
    )

    match ||= self.integration_item.integration_sync_matches.find_or_initialize_by(
      integration_syncable_type: syncable_type,
      sync_type: sync_type,
      sync_id: sync_id
    )

    match.integration_syncable = syncable_object
    match.sync_id = sync_id
    match.sync_alt_id = sync_alt_id if sync_alt_id.present?
    match.sync_object_created_at = sync_object_created_at
    match.sync_object_updated_at = sync_object_updated_at
    match.no_sync = true
  end

  def qbd_create_step(step_hash, parent_step_id = nil, sync_id = nil)
    step_hash = step_hash.as_json
    # parent_step_id ||= self.current_step.try(:id)
    next_position = self.integration_steps.order(position: :desc).first.try(:position).to_i + 1
    if step_hash.fetch(:force_create, false)
      integration_step = self.integration_steps.new(
        sync_type: step_hash.fetch('qbxml_class', nil),
        integrationable_type: step_hash.fetch('object_class', nil),
        integration_syncable_id: step_hash.fetch('object_id', nil)
      )
    else
      integration_step = self.integration_steps.incomplete.find_or_initialize_by(
        sync_type: step_hash.fetch('qbxml_class', nil),
        integrationable_type: step_hash.fetch('object_class', nil),
        integration_syncable_id: step_hash.fetch('object_id', nil)
      )
    end

    integration_step.parent_id = parent_step_id unless parent_step_id == integration_step.id
    integration_step.details = step_hash
    integration_step.position = next_position
    integration_step.save

    integration_step
  end

  def qbd_overwrite_in_qbd?
    self.integration_item.overwrite_conflicts_in == 'quickbooks'
  end

  def qbd_overwrite_in_sweet?
    self.integration_item.overwrite_conflicts_in == 'sweet'
  end

  def qbd_no_resolution?
    !(qbd_overwrite_in_sweet? || qbd_overwrite_in_qbd?)
  end

end
