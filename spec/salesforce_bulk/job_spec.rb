require 'spec_helper'
require 'xmlsimple'
require 'salesforce_bulk/job'
require 'salesforce_bulk/connection'
require 'csv'

RSpec.describe SalesforceBulk::Job do
  let (:version) { "34.0" }
  let (:job_id) { "some-job-id" }
  let (:batch_id) { "some-batch-id" }
  let (:operation) { "query" } # query or update
  let (:sobject) { "Lead" }
  let (:records_or_query) {}
  let (:external_field) { nil } # It's always nil for the operations we use
  let (:xml_headers) { {'Content-Type' => 'application/xml; charset=utf-8'} }
  let (:connection) {
    # https://trailhead.salesforce.com/content/learn/modules/api_basics/api_basics_soap
      allow_any_instance_of(SalesforceBulk::Connection).to receive(:post_xml).with("test.salesforce.com", "/services/Soap/u/34.0", '<?xml version="1.0" encoding="utf-8" ?><env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema"    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"    xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">  <env:Body>    <n1:login xmlns:n1="urn:partner.soap.sforce.com">      <n1:username>pirate_jack@trailhead-pirates.org</n1:username>      <n1:password>2dRh4HVDCJjFvRJu5ivMV03pMQ</n1:password>    </n1:login>  </env:Body></env:Envelope>', {'Content-Type' => 'text/xml; charset=utf-8', 'SOAPAction' => 'login'}).and_return('<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="urn:partner.soap.sforce.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><loginResponse><result><metadataServerUrl>metadataserverurl</metadataServerUrl><passwordExpired>false</passwordExpired><sandbox>true</sandbox><serverUrl>sandboxserverurl.tld</serverUrl><sessionId>some-session-id</sessionId><userId>blahblahuserId</userId><userInfo><accessibilityMode>false</accessibilityMode><currencySymbol>$</currencySymbol><orgAttachmentFileSizeLimit>5242880</orgAttachmentFileSizeLimit><orgDefaultCurrencyIsoCode>USD</orgDefaultCurrencyIsoCode><orgDisallowHtmlAttachments>false</orgDisallowHtmlAttachments><orgHasPersonAccounts>false</orgHasPersonAccounts><organizationId>blahblahorgId</organizationId><organizationMultiCurrency>false</organizationMultiCurrency><organizationName>Justworks</organizationName><profileId>blahblahprofileID</profileId><roleId xsi:nil="true"/><sessionSecondsValid>7200</sessionSecondsValid><userDefaultCurrencyIsoCode xsi:nil="true"/><userEmail>blahblahemail@justworks.com</userEmail><userFullName>Payroll Service</userFullName><userId>blahblahuserId</userId><userLanguage>en_US</userLanguage><userLocale>en_US</userLocale><userName>blahblahusername</userName><userTimeZone>America/New_York</userTimeZone><userType>Standard</userType><userUiSkin>Theme3</userUiSkin></userInfo></result></loginResponse></soapenv:Body></soapenv:Envelope>')
      SalesforceBulk::Connection.new("pirate_jack@trailhead-pirates.org", "2dRh4HVDCJjFvRJu5ivMV03pMQ", version, true)
    }


  # The responses are based off version 34.0
  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_jobs_close.htm
  # The things we chose to test are based on existing usage in Clockwork, which is `query` and `update`. These underlyingly call the following tested functions.

  describe '#initialize' do
    it 'creates a new instance of the Job class' do
      job = described_class.new(operation, sobject, records_or_query, external_field, connection)
      expect(job).to be_an_instance_of(SalesforceBulk::Job)
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_jobs_create.htm
  describe '#create_job' do
    it 'can adhere to the contract with Salesforce' do
      allow(connection).to receive(:post_xml).with(nil, "job", '<?xml version="1.0" encoding="utf-8" ?><jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload"><operation>' + operation + '</operation><object>' + sobject + '</object><contentType>CSV</contentType></jobInfo>', xml_headers).and_return('<?xml version="1.0" encoding="UTF-8"?><jobInfo
   xmlns="http://www.force.com/2009/06/asyncapi/dataload">
 <id>' + job_id + '</id>
 <operation>' + operation + '</operation>
 <object>' + sobject + '</object>
 <createdById>005PJ000002voWnYAI</createdById>
 <createdDate>2025-10-17T16:42:34.000Z</createdDate>
 <systemModstamp>2025-10-17T16:42:34.000Z</systemModstamp>
 <state>Open</state>
 <concurrencyMode>Parallel</concurrencyMode>
 <contentType>CSV</contentType>
 <numberBatchesQueued>0</numberBatchesQueued>
 <numberBatchesInProgress>0</numberBatchesInProgress>
 <numberBatchesCompleted>0</numberBatchesCompleted>
 <numberBatchesFailed>0</numberBatchesFailed>
 <numberBatchesTotal>0</numberBatchesTotal>
 <numberRecordsProcessed>0</numberRecordsProcessed>
 <numberRetries>0</numberRetries>
 <apiVersion>34.0</apiVersion>
 <numberRecordsFailed>0</numberRecordsFailed>
 <totalProcessingTime>0</totalProcessingTime>
 <apiActiveProcessingTime>0</apiActiveProcessingTime>
 <apexProcessingTime>0</apexProcessingTime>
</jobInfo>')

      actual_job_id = described_class.new(operation, sobject, records_or_query, external_field, connection).create_job
      expect(actual_job_id).to eq(job_id)
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_jobs_close.htm
  describe '#close_job' do
    it 'can adhere to the contract with Salesforce' do
      instance = described_class.new(operation, sobject, records_or_query, external_field, connection)
      described_class.class_variable_set(:@@job_id, job_id)

      allow(connection).to receive(:post_xml).with(nil, "job/#{job_id}", '<?xml version="1.0" encoding="utf-8" ?><jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload"><state>Closed</state></jobInfo>', xml_headers).and_return('<?xml version="1.0" encoding="UTF-8"?><jobInfo
   xmlns="http://www.force.com/2009/06/asyncapi/dataload">
 <id>' + job_id + '</id>
 <operation>' + operation + '</operation>
 <object>' + sobject + '</object>
 <createdById>005PJ000002voWnYAI</createdById>
 <createdDate>2025-10-17T16:42:34.000Z</createdDate>
 <systemModstamp>2025-10-17T16:42:34.000Z</systemModstamp>
 <state>Closed</state>
 <concurrencyMode>Parallel</concurrencyMode>
 <contentType>CSV</contentType>
 <numberBatchesQueued>0</numberBatchesQueued>
 <numberBatchesInProgress>0</numberBatchesInProgress>
 <numberBatchesCompleted>1</numberBatchesCompleted>
 <numberBatchesFailed>0</numberBatchesFailed>
 <numberBatchesTotal>1</numberBatchesTotal>
 <numberRecordsProcessed>10</numberRecordsProcessed>
 <numberRetries>0</numberRetries>
 <apiVersion>34.0</apiVersion>
 <numberRecordsFailed>0</numberRecordsFailed>
 <totalProcessingTime>0</totalProcessingTime>
 <apiActiveProcessingTime>0</apiActiveProcessingTime>
 <apexProcessingTime>0</apexProcessingTime>
</jobInfo>')

      expect(described_class.new(operation, sobject, records_or_query, external_field, connection).close_job).to eq({"apexProcessingTime" => ["0"], "apiActiveProcessingTime" => ["0"], "apiVersion" => [version], "concurrencyMode" => ["Parallel"], "contentType" => ["CSV"], "createdById" => ["005PJ000002voWnYAI"], "createdDate" => ["2025-10-17T16:42:34.000Z"], "id" => ["some-job-id"], "numberBatchesCompleted" => ["1"], "numberBatchesFailed" => ["0"], "numberBatchesInProgress" => ["0"], "numberBatchesQueued" => ["0"], "numberBatchesTotal" => ["1"], "numberRecordsFailed" => ["0"], "numberRecordsProcessed" => ["10"], "numberRetries" => ["0"], "object" => ["Lead"], "operation" => ["query"], "state" => ["Closed"], "systemModstamp" => ["2025-10-17T16:42:34.000Z"], "totalProcessingTime" => ["0"], "xmlns" => "http://www.force.com/2009/06/asyncapi/dataload"})
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_using_bulk_query.htm
  describe '#add_query' do
    let (:records_or_query)  { "select Id, Company_ID__c, OwnerId, IsConverted from Lead where Company_ID__c != null limit 10" }
    let (:xml_headers) { {"Content-Type" => "text/csv; charset=UTF-8"} }

    it 'can adhere to the contract with Salesforce' do
      instance = described_class.new(operation, sobject, records_or_query, external_field, connection)
      described_class.class_variable_set(:@@job_id, job_id)

      batch_id = "some-batch-id"

      allow(connection).to receive(:post_xml).with(nil, "job/#{job_id}/batch/", records_or_query, xml_headers).and_return('<?xml version="1.0" encoding="UTF-8"?><batchInfo
   xmlns="http://www.force.com/2009/06/asyncapi/dataload">
 <id>' + batch_id + '</id>
 <jobId>' + job_id + '</jobId>
 <state>Queued</state>
 <createdDate>2025-10-17T17:38:20.000Z</createdDate>
 <systemModstamp>2025-10-17T17:38:20.000Z</systemModstamp>
 <numberRecordsProcessed>0</numberRecordsProcessed>
 <numberRecordsFailed>0</numberRecordsFailed>
 <totalProcessingTime>0</totalProcessingTime>
 <apiActiveProcessingTime>0</apiActiveProcessingTime>
 <apexProcessingTime>0</apexProcessingTime>
</batchInfo>')

      expect(described_class.new(operation, sobject, records_or_query, external_field, connection).add_query).to eq(batch_id)
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_batches_create.htm
  describe '#add_batch' do
    let (:operation) { "update" }
    let (:records_or_query) { [
      {"Company_ID__c": "C123456", "IsConverted": true},
      {"Company_ID__c": "C234567", "IsConverted": true}
    ] }
    let (:xml_headers) { { "Content-Type" => "text/csv; charset=UTF-8" } }

    it 'can adhere to the contract with Salesforce' do
      instance = described_class.new(operation, sobject, records_or_query, external_field, connection)
      described_class.class_variable_set(:@@job_id, job_id)
      batch_id = "some-batch-id"

      allow(connection).to receive(:post_xml).with(nil, "job/#{job_id}/batch/", "Company_ID__c,IsConverted\nC123456,true\nC234567,true\n", xml_headers).and_return('<?xml version="1.0" encoding="UTF-8"?>
<batchInfo
   xmlns="http://www.force.com/2009/06/asyncapi/dataload">
 <id>' + batch_id + '</id>
 <jobId>' + job_id + '</jobId>
 <state>Queued</state>
 <createdDate>2009-04-14T18:15:59.000Z</createdDate>
 <systemModstamp>2009-04-14T18:15:59.000Z</systemModstamp>
 <numberRecordsProcessed>0</numberRecordsProcessed>
</batchInfo>')

      expect(described_class.new(operation, sobject, records_or_query, external_field, connection).add_batch).to eq(batch_id)
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_batches_get_info_all.htm
  describe '#fetch_pk_batch_ids' do
    it 'can adhere to the contract with Salesforce' do
      instance = described_class.new(operation, sobject, records_or_query, external_field, connection)
      described_class.class_variable_set(:@@job_id, job_id)
      described_class.class_variable_set(:@@batch_id, batch_id)

      allow(connection).to receive(:get_request).with(nil, "job/#{job_id}/batch", Hash.new).and_return('<?xml version="1.0" encoding="UTF-8"?>
<batchInfoList
   xmlns="http://www.force.com/2009/06/asyncapi/dataload">
 <batchInfo>
  <id>751D0000000004rIAA</id>
  <jobId>750D0000000002lIAA</jobId>
  <state>InProgress</state>
  <createdDate>2009-04-14T18:15:59.000Z</createdDate>
  <systemModstamp>2009-04-14T18:16:09.000Z</systemModstamp>
  <numberRecordsProcessed>800</numberRecordsProcessed>
 </batchInfo>
 <batchInfo>
  <id>751D0000000004sIAA</id>
  <jobId>750D0000000002lIAA</jobId>
  <state>InProgress</state>
  <createdDate>2009-04-14T18:16:00.000Z</createdDate>
  <systemModstamp>2009-04-14T18:16:09.000Z</systemModstamp>
  <numberRecordsProcessed>800</numberRecordsProcessed>
 </batchInfo>
</batchInfoList>')

      expect(described_class.new(operation, sobject, records_or_query, external_field, connection).fetch_pk_batch_ids).to eq(["751D0000000004rIAA", "751D0000000004sIAA"])
      # test class member
      # do the above fdor other functions
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_batches_get_info.htm
  describe '#check_batch_status' do
    it 'can adhere to the contract with Salesforce' do
      instance = described_class.new(operation, sobject, records_or_query, external_field, connection)
      described_class.class_variable_set(:@@job_id, job_id)
      described_class.class_variable_set(:@@batch_id, batch_id)

      allow(connection).to receive(:get_request).with(nil, "job/#{job_id}/batch/#{batch_id}", Hash.new).and_return('<?xml version="1.0" encoding="UTF-8"?><batchInfo
   xmlns="http://www.force.com/2009/06/asyncapi/dataload">
 <id>' + batch_id + '</id>
 <jobId>' + job_id + '</jobId>
 <state>Queued</state>
 <createdDate>2025-10-17T16:42:34.000Z</createdDate>
 <systemModstamp>2025-10-17T16:42:34.000Z</systemModstamp>
 <numberRecordsProcessed>0</numberRecordsProcessed>
 <numberRecordsFailed>0</numberRecordsFailed>
 <totalProcessingTime>0</totalProcessingTime>
 <apiActiveProcessingTime>0</apiActiveProcessingTime>
 <apexProcessingTime>0</apexProcessingTime>
</batchInfo>')

      expect(described_class.new(operation, sobject, records_or_query, external_field, connection).check_batch_status).to eq("Queued")
    end
  end

  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_batches_get_results.htm
  # https://developer.salesforce.com/docs/atlas.en-us.196.0.api_asynch.meta/api_asynch/asynch_api_code_curl_walkthrough.htm
  describe '#get_batch_result' do
    let (:xml_headers) { {"Content-Type"=>"text/xml; charset=UTF-8"} }

    it 'can adhere to the contract with Salesforce' do
      instance = described_class.new(operation, sobject, records_or_query, external_field, connection)
      described_class.class_variable_set(:@@job_id, job_id)
      described_class.class_variable_set(:@@batch_id, batch_id)
      result_id = 'some-result-id'

      allow(connection).to receive(:get_request).with(nil, "job/#{job_id}/batch/#{batch_id}/result", xml_headers).and_return('<result-list xmlns="http://www.force.com/2009/06/asyncapi/dataload"><result>' + result_id + '</result></result-list>')
      allow(connection).to receive(:get_request).with(nil, "job/#{job_id}/batch/#{batch_id}/result/#{result_id}", xml_headers).and_return('"Id","Company_ID__c","OwnerId","IsConverted"
"00QccsalesforceID1","C123456","005PothersalesforceID1","false"
"00QccsalesforceID2","C234567","005PothersalesforceID2","false"')

      expect(described_class.new(operation, sobject, records_or_query, external_field, connection).get_batch_result).to eq("\"00QccsalesforceID1\",\"C123456\",\"005PothersalesforceID1\",\"false\"
\"00QccsalesforceID2\",\"C234567\",\"005PothersalesforceID2\",\"false\"")
    end
  end
end