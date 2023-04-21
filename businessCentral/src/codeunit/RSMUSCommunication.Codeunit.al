// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82662 "RSMUS Communication"
{
    Access = Internal;

    var
        rsmusCredentials: Codeunit "RSMUS Credentials";
        CompanyID: Guid;
        TableID: Integer;
        //sv.begin
        ExportFormat: Enum "RSMUS Data Export Format";
        StripEscapedDblQuotes: Boolean;
        //sv.end

        FieldIdList: List of [Integer];
        DataBlobPath: Text;
        DataBlobBlockIDs: List of [Text];
        LastRecordOnPayloadTimeStamp: BigInteger;
        TestRecordTime: DateTime;
        Payload: TextBuilder;
        jobjTableData: JsonObject;
        jarrRecords: JsonArray;
        JsonPayloadSize: Integer;

        LastFlushedTimeStamp: BigInteger;
        EntityName: Text;
        NumberOfFlushes: Integer;
        //EntityName: Text;
        EntityJson: JsonObject;
        DefaultContainerName: Text;
        MaxSizeOfPayloadMiB: Integer;
        SplitBlobsByPayloadSize: Boolean;
        EmitTelemetry: Boolean;
        DeltaCdmManifestNameTxt: Label 'deltas.manifest.cdm.json', Locked = true;
        DataCdmManifestNameTxt: Label 'data.manifest.cdm.json', Locked = true;
        EntityManifestNameTemplateTxt: Label '%1.cdm.json', Locked = true, Comment = '%1 = Entity name';
        ContainerUrlTxt: Label 'https://%1.blob.core.windows.net/%2', Comment = '%1: Account name, %2: Container Name';
        CorpusJsonPathTxt: Label '/%1', Comment = '%1 = name of the blob', Locked = true;
        CannotAddedMoreBlocksErr: Label 'The number of blocks that can be added to the blob has reached its maximum limit.';
        SingleRecordTooLargeErr: Label 'A single record payload exceeded the max payload size. Please adjust the payload size or reduce the fields to be exported for the record.';
        DeltasFileCsvTok: Label '/deltas/%1/%2.csv', Comment = '%1: Entity, %2: File identifier guid';
        NotAllowedOnSimultaneousExportTxt: Label 'This is not allowed when exports are configured to occur simultaneously. Please uncheck Multi- company export, export the data at least once, and try again.';
        EntitySchemaChangedErr: Label 'The schema of the table %1 has changed. %2', Comment = '%1 = Entity name, %2 = NotAllowedOnSimultaneousExportTxt';
        CdmSchemaChangedErr: Label 'There may have been a change in the tables to export. %1', Comment = '%1 = NotAllowedOnSimultaneousExportTxt';
        ManifestJsonsNotUpdatedErr: Label 'Could not update the CDM manifest files because of a race condition. Please try again later.';

    procedure SetupBlobStorage()
    var
        rsmusGen2Util: Codeunit "RSMUS Gen 2 Util";

    begin
        rsmusCredentials.Init();
        if not rsmusGen2Util.ContainerExists(GetBaseUrl(), rsmusCredentials) then
            rsmusGen2Util.CreateContainer(GetBaseUrl(), rsmusCredentials);
    end;

    local procedure GetBaseUrl(): Text
    var
        rsmusSetup: Record "RSMUS Setup";
    begin
        if DefaultContainerName = '' then begin
            rsmusSetup.GetSingleton();
            DefaultContainerName := rsmusSetup.Container;
        end;
        exit(StrSubstNo(ContainerUrlTxt, rsmusCredentials.GetStorageAccount(), DefaultContainerName));
    end;

    procedure Init(TableIDValue: Integer; ExportFormatValue: Enum "RSMUS Data Export Format"; StripEscapedDblQuotesValue: Boolean; FieldIdListValue: List of [Integer]; TestRecordTimeValue: DateTime; LastFlushedTimeStampValue: BigInteger; EmitTelemetryValue: Boolean)
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusUtil: Codeunit "RSMUS Util";
        Companies: Record Company;
    begin
        TableID := TableIDValue;
        StripEscapedDblQuotes := StripEscapedDblQuotesValue;
        ExportFormat := ExportFormatValue;
        FieldIdList := FieldIdListValue;

        rsmusCredentials.Init();
        EntityName := rsmusUtil.GetDataLakeCompliantTableName(TableID);

        LastFlushedTimeStamp := LastFlushedTimeStampValue;
        TestRecordTime := TestRecordTimeValue;
        rsmusSetup.GetSingleton();
        MaxSizeOfPayloadMiB := rsmusSetup.MaxPayloadSizeMiB;
        SplitBlobsByPayloadSize := rsmusSetup.SplitBlobsByPayloadSize;
        EmitTelemetry := EmitTelemetryValue;

        //sv.begin
        Companies.SetRange(Name, CompanyName());
        Companies.FindFirst();
        CompanyID := Companies.Id;
        //sv.end
    end;

    procedure CheckEntity(CdmDataFormat: Enum "RSMUS Data Export Format"; var EntityJsonNeedsUpdate: Boolean; var ManifestJsonsNeedsUpdate: Boolean)
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusCdmUtil: Codeunit "RSMUS CDM Util";
        rsmusGen2Util: Codeunit "RSMUS Gen 2 Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        OldJson: JsonObject;
        NewJson: JsonObject;
        BlobExists: Boolean;
        BlobEntityPath: Text;
    begin
        // check entity
        EntityJson := rsmusCdmUtil.CreateEntityContent(TableID, FieldIdList);
        BlobEntityPath := StrSubstNo(CorpusJsonPathTxt, StrSubstNo(EntityManifestNameTemplateTxt, EntityName));
        OldJson := rsmusGen2Util.GetBlobContent(GetBaseUrl() + BlobEntityPath, rsmusCredentials, BlobExists);
        if BlobExists then
            rsmusCdmUtil.CheckChangeInEntities(OldJson, EntityJson, EntityName);
        if not rsmusCdmUtil.CompareEntityJsons(OldJson, EntityJson) then begin
            if EmitTelemetry then
                rsmusExecution.Log('ADLSE-028', GetLastErrorText() + GetLastErrorCallStack(), Verbosity::Warning, DataClassification::SystemMetadata);
            ClearLastError();

            EntityJsonNeedsUpdate := true;
            JsonsDifferent(OldJson, EntityJson); // to log the difference
        end;

        // check manifest. Assume that if the data manifest needs change, the delta manifest will also need be updated
        OldJson := rsmusGen2Util.GetBlobContent(GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, DataCdmManifestNameTxt), rsmusCredentials, BlobExists);
        NewJson := rsmusCdmUtil.UpdateDefaultManifestContent(OldJson, TableID, 'data', CdmDataFormat);
        ManifestJsonsNeedsUpdate := JsonsDifferent(OldJson, NewJson);

        rsmusSetup.GetSingleton();
        if rsmusSetup."Multi- Company Export" then begin
            if EntityJsonNeedsUpdate then
                Error(EntitySchemaChangedErr, EntityName, NotAllowedOnSimultaneousExportTxt);
            if ManifestJsonsNeedsUpdate then
                Error(CdmSchemaChangedErr, NotAllowedOnSimultaneousExportTxt);
        end;
    end;

    local procedure JsonsDifferent(Json1: JsonObject; Json2: JsonObject) Result: Boolean
    var
        rsmusExecution: Codeunit "RSMUS Execution";
        CustomDimensions: Dictionary of [Text, Text];
        Content1: Text;
        Content2: Text;
    begin
        Json1.WriteTo(Content1);
        Json2.WriteTo(Content2);
        Result := Content1 <> Content2;
        if Result and EmitTelemetry then begin
            CustomDimensions.Add('Content1', Content1);
            CustomDimensions.Add('Content2', Content2);
            rsmusExecution.Log('ADLSE-023', 'Jsons were found to be different.', Verbosity::Warning, DataClassification::SystemMetadata, CustomDimensions);
        end;
    end;

    local procedure CreateDataBlob(ExportFormat: Enum "RSMUS Data Export Format")
    var
        rsmusUtil: Codeunit "RSMUS Util";
        rsmusGen2Util: Codeunit "RSMUS Gen 2 Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        CustomDimension: Dictionary of [Text, Text];
        FileIdentifer: Guid;
        //sv.begin
        CSVDataBlobPathTxt: Label '/deltas/%1/%2.csv', Comment = '%1: EntityName, %2: FileId';
        JsonDataBlobPathTxt: Label '/deltas/%1/%2.json', Comment = '%1: EntityName, %2: FileId';
    //sv.end
    begin
        if DataBlobPath <> '' then
            // already created blob
            exit;
        FileIdentifer := CreateGuid();
        //sv.begin
        //DataBlobPath := StrSubstNo(DeltasFileCsvTok, EntityName, rsmusUtil.ToText(FileIdentifer));

        case ExportFormat of
            ExportFormat::CSV:
                DataBlobPath := StrSubstNo(CSVDataBlobPathTxt, EntityName, rsmusUtil.ToText(FileIdentifer));
            ExportFormat::JSON:
                DataBlobPath := StrSubstNo(JsonDataBlobPathTxt, EntityName, rsmusUtil.ToText(FileIdentifer));
        end;
        //sv.end
        rsmusGen2Util.CreateDataBlob(GetBaseUrl() + DataBlobPath, rsmusCredentials, ExportFormat);
        if EmitTelemetry then begin
            CustomDimension.Add('Entity', EntityName);//sv see if we need to add DataBlobPath here
            rsmusExecution.Log('ADLSE-012', 'Created new blob to hold the data to be exported', Verbosity::Verbose, DataClassification::SystemMetadata, CustomDimension);
        end;
    end;

    [TryFunction]
    procedure TryCollectAndSendRecord(Rec: RecordRef; isDelete: Boolean; RecordTimeStamp: BigInteger; var LastTimestampExported: BigInteger; ExportFormat: Enum "RSMUS Data Export Format")
    begin
        ClearLastError();
        CreateDataBlob(ExportFormat);
        LastTimestampExported := CollectAndSendRecord(Rec, isDelete, RecordTimeStamp, ExportFormat);
    end;

    local procedure CollectAndSendRecord(Rec: RecordRef; isDelete: Boolean; RecordTimeStamp: BigInteger; ExportFormat: Enum "RSMUS Data Export Format") LastTimestampExported: BigInteger
    var
        rsmusUtil: Codeunit "RSMUS Util";
        CreatedDateField: FieldRef;
        CreatedDateValue: DateTime;
        ChangeType: Enum "RSMUS Change Type";
        CSVRecordPayLoad: Text;
        JsonRecordPayload: JsonObject;
        JsonRecordSize: Integer;
    begin
        if NumberOfFlushes = 50000 then // https://docs.microsoft.com/en-us/rest/api/storageservices/put-block#remarks
            Error(CannotAddedMoreBlocksErr);

        if IsDelete then
            ChangeType := ChangeType::deleted
        else begin
            CreatedDateField := Rec.Field(2000000001);
            CreatedDateValue := CreatedDateField.Value();
            if (CreatedDateValue > TestRecordTime) or (CreatedDateValue = 0DT) then begin
                ChangeType := ChangeType::created;
                //RowCount += 1;
            end else
                ChangeType := ChangeType::updated;
        end;

        // RecordPayLoad := rsmusUtil.CreateCsvPayload(Rec, FieldIdList, Payload.Length() = 0);
        // // check if payload exceeds the limit
        // if Payload.Length() + StrLen(RecordPayLoad) + 2 > MaxPayloadSize() then begin // the 2 is to account for new line characters
        //     if Payload.Length() = 0 then
        //         // the record alone exceeds the max payload size
        //         Error(SingleRecordTooLargeErr);
        //     FlushPayload();
        // end;
        LastTimestampExported := LastFlushedTimeStamp;

        // Payload.Append(RecordPayLoad);
        LastRecordOnPayloadTimeStamp := RecordTimestamp;

        //sv+.begin
        case ExportFormat of
            ExportFormat::CSV:
                begin
                    CSVRecordPayLoad := rsmusUtil.CreateCsvPayload(Rec, FieldIdList, Payload.Length() = 0);
                    // check if payload exceeds the limit
                    if Payload.Length() + StrLen(CSVRecordPayLoad) + 2 > MaxPayloadSize() then begin // the 2 is to account for new line characters
                        if Payload.Length() = 0 then
                            Error(SingleRecordTooLargeErr);
                        FlushPayload();
                    end;
                    Payload.Append(CSVRecordPayLoad);
                end;
            ExportFormat::JSON:
                begin
                    JsonRecordSize := 0;
                    JsonRecordPayload := rsmusUtil.CreateJsonPayload(Rec, FieldIdList, CompanyID, ChangeType, JsonRecordSize);

                    // check if payload exceeds the limit
                    if JsonPayloadSize + JsonRecordSize > MaxPayloadSize() then begin
                        if JsonPayloadSize = 0 then
                            // the record alone exceeds the max payload size
                            Error(SingleRecordTooLargeErr);
                        FlushPayload();
                    end;
                    JsonPayloadSize := JsonPayloadSize + JsonRecordSize;
                    jarrRecords.Add(JsonRecordPayload);
                end;
        end;

        // LastRowVersionExported := LastFlushedRowVersion;
        // LastRecordTimeExported := LastFlushedRecordTime;
        // LastRecordOnPayloadRowVersion := RecordRowVersion;
        // LastRecordOnPayloadRecordTime := RecordTimeValue;
        //sv+.emd
    end;

    [TryFunction]
    procedure TryFinish(var LastTimestampExported: BigInteger)
    begin
        ClearLastError();
        LastTimestampExported := Finish();
    end;

    local procedure Finish() LastTimestampExported: BigInteger
    begin
        FlushPayload();
        LastTimestampExported := LastFlushedTimeStamp;
    end;

    local procedure MaxPayloadSize(): Integer
    var
        MaxLimitForPutBlockCalls: Integer;
        MaxCapacityOfTextBuilder: Integer;
    begin
        MaxLimitForPutBlockCalls := MaxSizeOfPayloadMiB * 1024 * 1024;
        MaxCapacityOfTextBuilder := Payload.MaxCapacity();
        if MaxLimitForPutBlockCalls < MaxCapacityOfTextBuilder then
            exit(MaxLimitForPutBlockCalls);
        exit(MaxCapacityOfTextBuilder);
    end;

    local procedure FlushPayload()
    var
        rsmusGen2Util: Codeunit "RSMUS Gen 2 Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        ADLSE: Codeunit "RSMUS ADLSE";
        CustomDimensions: Dictionary of [Text, Text];
        BlockID: Text;
        TempPayload: Text;
    begin
        if (ExportFormat = ExportFormat::JSON) and (JsonPayloadSize <> 0) then begin
            // Finalize the Table JsonObject
            jobjTableData.Add(EntityName, jarrRecords);
            jobjTableData.WriteTo(TempPayload);

            if StripEscapedDblQuotes then
                TempPayload := TempPayload.Replace('\"', '');

            Payload.Append(TempPayload);
        end;

        if Payload.Length() = 0 then
            exit;

        if EmitTelemetry then begin
            CustomDimensions.Add('Length of payload', Format(Payload.Length()));
            rsmusExecution.Log('ADLSE-013', 'Flushing the payload', Verbosity::Verbose, DataClassification::SystemMetadata, CustomDimensions);
        end;

        BlockID := rsmusGen2Util.AddBlockToDataBlob(GetBaseUrl() + DataBlobPath, Payload.ToText(), rsmusCredentials);
        if EmitTelemetry then begin
            Clear(CustomDimensions);
            CustomDimensions.Add('Block ID', BlockID);
            rsmusExecution.Log('ADLSE-014', 'Block added to blob', Verbosity::Verbose, DataClassification::SystemMetadata, CustomDimensions);
        end;
        DataBlobBlockIDs.Add(BlockID);
        rsmusGen2Util.CommitAllBlocksOnDataBlob(GetBaseUrl() + DataBlobPath, rsmusCredentials, DataBlobBlockIDs);
        if EmitTelemetry then
            rsmusExecution.Log('ADLSE-015', 'Block committed', Verbosity::Verbose, DataClassification::SystemMetadata);

        LastFlushedTimeStamp := LastRecordOnPayloadTimeStamp;
        Payload.Clear();
        Clear(jobjTableData);
        Clear(jarrRecords);
        JsonPayloadSize := 0;
        LastRecordOnPayloadTimeStamp := 0;
        if SplitBlobsByPayloadSize then begin
            DataBlobPath := '';
            Clear(DataBlobBlockIDs);
        end;
        NumberOfFlushes += 1;

        ADLSE.OnTableExported(TableID, LastFlushedTimeStamp);
        if EmitTelemetry then begin
            Clear(CustomDimensions);
            if SplitBlobsByPayloadSize then begin
                CustomDimensions.Add('Blobs count', Format(NumberOfFlushes));
                rsmusExecution.Log('ADLSE-016', 'Finalized Blob', Verbosity::Normal, DataClassification::CustomerContent, CustomDimensions);
            end else begin
                CustomDimensions.Add('Flushed count', Format(NumberOfFlushes));
                rsmusExecution.Log('ADLSE-016', 'Flushed the payload', Verbosity::Normal, DataClassification::CustomerContent, CustomDimensions);
            end;
        end;
    end;

    [TryFunction]
    procedure TryUpdateCdmJsons(EntityJsonNeedsUpdate: Boolean; ManifestJsonsNeedsUpdate: Boolean)
    begin
        UpdateCdmJsons(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate);
    end;

    local procedure UpdateCdmJsons(EntityJsonNeedsUpdate: Boolean; ManifestJsonsNeedsUpdate: Boolean)
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusGen2Util: Codeunit "RSMUS Gen 2 Util";
        LeaseID: Text;
        BlobPath: Text;
        BlobExists: Boolean;
    begin
        // update entity json
        if EntityJsonNeedsUpdate then begin
            BlobPath := GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, StrSubstNo(EntityManifestNameTemplateTxt, EntityName));
            LeaseID := rsmusGen2Util.AcquireLease(BlobPath, rsmusCredentials, BlobExists);
            rsmusGen2Util.CreateOrUpdateJsonBlob(BlobPath, rsmusCredentials, LeaseID, EntityJson);
            rsmusGen2Util.ReleaseBlob(BlobPath, rsmusCredentials, LeaseID);
        end;

        // update manifest
        if ManifestJsonsNeedsUpdate then begin
            // Expected that multiple sessions that export data from different tables will be competing for writing to 
            // manifest. Semaphore applied.
            if not AcquireLockonADLSESetup(rsmusSetup) then
                Error(ManifestJsonsNotUpdatedErr);

            UpdateManifest(GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, DataCdmManifestNameTxt), 'data', rsmusSetup.DataExportFormat);
            UpdateManifest(GetBaseUrl() + StrSubstNo(CorpusJsonPathTxt, DeltaCdmManifestNameTxt), 'deltas', "RSMUS Data Export Format"::Csv);
            Commit(); // to release the lock above
        end;
    end;

    [TryFunction]
    local procedure AcquireLockonADLSESetup(var rsmusSetup: Record "RSMUS Setup")
    begin
        rsmusSetup.LockTable(true);
        rsmusSetup.GetSingleton();
    end;

    local procedure UpdateManifest(BlobPath: Text; Folder: Text; rsmusCdmFormat: Enum "RSMUS Data Export Format")
    var
        rsmusCdmUtil: Codeunit "RSMUS CDM Util";
        rsmusGen2Util: Codeunit "RSMUS Gen 2 Util";
        ManifestJson: JsonObject;
        LeaseID: Text;
        BlobExists: Boolean;
    begin
        LeaseID := rsmusGen2Util.AcquireLease(BlobPath, rsmusCredentials, BlobExists);
        if BlobExists then
            ManifestJson := rsmusGen2Util.GetBlobContent(BlobPath, rsmusCredentials, BlobExists);
        ManifestJson := rsmusCdmUtil.UpdateDefaultManifestContent(ManifestJson, TableID, Folder, rsmusCdmFormat);
        rsmusGen2Util.CreateOrUpdateJsonBlob(BlobPath, rsmusCredentials, LeaseID, ManifestJson);
        rsmusGen2Util.ReleaseBlob(BlobPath, rsmusCredentials, LeaseID);
    end;

}