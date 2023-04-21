// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82661 "RSMUS Execute"
{
    Access = Internal;
    TableNo = "RSMUS Table";

    trigger OnRun()
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusRunLog: Record "RSMUS Runs Log";
        rsmusCurrentSession: Record "RSMUS Current Session";
        rsmusTableLastTimestamp: Record "RSMUS Table Tracking";
        rsmusCommunication: Codeunit "RSMUS Communication";
        rsmusExecution: Codeunit "RSMUS Execution";
        rsmusUtil: Codeunit "RSMUS Util";
        CustomDimensions: Dictionary of [Text, Text];
        UpdatedLastRecordTime: DateTime;
        TableCaption: Text;
        UpdatedLastTimestamp: BigInteger;
        DeletedLastEntryNo: BigInteger;
        OldUpdatedLastTimestamp: BigInteger;
        OldDeletedLastEntryNo: BigInteger;
        TestRecordTime: DateTime;
        EntityJsonNeedsUpdate: Boolean;
        ManifestJsonsNeedsUpdate: Boolean;
    begin
        rsmusSetup.GetSingleton();
        EmitTelemetry := rsmusSetup."Emit telemetry";
        CDMDataFormat := rsmusSetup.DataExportFormat;

        if EmitTelemetry then begin
            TableCaption := rsmusUtil.GetTableCaption(Rec."Table ID");
            CustomDimensions.Add('Entity', TableCaption);
            rsmusExecution.Log('ADLSE-017', 'Starting the export for table', Verbosity::Normal, Dataclassification::ToBeClassified, CustomDimensions);
        end;

        // Register session started
        rsmusCurrentSession.Start(Rec."Table ID");
        rsmusRunLog.RegisterStarted(Rec."Table ID");
        Commit(); // to release locks on the "ADLSE Current Session" record thus allowing other sessions to check for it being active when they are nearing the last step.
        if EmitTelemetry then
            rsmusExecution.Log('ADLSE-018', 'Registered session to export table', Verbosity::Verbose, Dataclassification::ToBeClassified, CustomDimensions);

        UpdatedLastTimestamp := rsmusTableLastTimestamp.GetUpdatedLastTimestamp(Rec."Table ID");
        DeletedLastEntryNo := rsmusTableLastTimestamp.GetDeletedLastEntryNo(Rec."Table ID");
        UpdatedLastRecordTime := rsmusTableLastTimestamp.GetUpdatedLastRecordTime(Rec."Table ID");

        if EmitTelemetry then begin
            CustomDimensions.Add('Old Updated Last time stamp', Format(UpdatedLastTimestamp));
            CustomDimensions.Add('Old Deleted Last entry no.', Format(DeletedLastEntryNo));
            rsmusExecution.Log('ADLSE-004', 'Exporting with parameters', Verbosity::Verbose, Dataclassification::ToBeClassified, CustomDimensions);
        end;

        // Perform the export 
        OldUpdatedLastTimestamp := UpdatedLastTimestamp;
        OldDeletedLastEntryNo := DeletedLastEntryNo;
        TestRecordTime := UpdatedLastRecordTime;
        if not TryExportTableData(Rec."Table ID", rsmusSetup.DataExportFormat, rsmusSetup.StripJSONEscapedDblQuotes, TestRecordTime, rsmusCommunication, UpdatedLastTimestamp, DeletedLastEntryNo, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
            SetStateFinished(Rec);
            exit;
        end;
        if EmitTelemetry then begin
            Clear(CustomDimensions);
            CustomDimensions.Add('Entity', TableCaption);
            CustomDimensions.Add('Updated Last time stamp', Format(UpdatedLastTimestamp));
            CustomDimensions.Add('Deleted Last entry no.', Format(DeletedLastEntryNo));
            CustomDimensions.Add('Entity Json needs update', Format(EntityJsonNeedsUpdate));
            CustomDimensions.Add('Manifest Json needs update', Format(ManifestJsonsNeedsUpdate));
            rsmusExecution.Log('ADLSE-020', 'Exported to deltas CDM folder', Verbosity::Verbose, Dataclassification::ToBeClassified, CustomDimensions);
        end;

        // check if anything exported at all
        if (UpdatedLastTimestamp > OldUpdatedLastTimestamp) or (DeletedLastEntryNo > OldDeletedLastEntryNo) then begin
            // update the last timestamps of the record
            if not rsmusTableLastTimestamp.TrySaveUpdatedLastTimestamp(Rec."Table ID", UpdatedLastTimestamp, EmitTelemetry) then begin
                SetStateFinished(Rec);
                exit;
            end;
            if not rsmusTableLastTimestamp.TrySaveDeletedLastEntryNo(Rec."Table ID", DeletedLastEntryNo, EmitTelemetry) then begin
                SetStateFinished(Rec);
                exit;
            end;
            if EmitTelemetry then begin
                Clear(CustomDimensions);
                CustomDimensions.Add('Entity', TableCaption);
                rsmusExecution.Log('ADLSE-006', 'Saved the timestamps into the database', Verbosity::Normal, Dataclassification::ToBeClassified, CustomDimensions);
            end;
            Commit(); // to save the last time stamps into the database.
        end;

        // update Jsons
        if not rsmusCommunication.TryUpdateCdmJsons(EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate) then begin
            SetStateFinished(Rec);
            exit;
        end;
        if EmitTelemetry then
            rsmusExecution.Log('ADLSE-007', 'Jsons have been updated', Verbosity::Normal, Dataclassification::ToBeClassified, CustomDimensions);

        // Finalize
        SetStateFinished(Rec);
        if EmitTelemetry then;
        rsmusExecution.Log('ADLSE-005', 'Export completed without error', Verbosity::Normal, Dataclassification::ToBeClassified, CustomDimensions);
    end;

    var
        TimestampAscendingSortViewTxt: Label 'Sorting(Timestamp) Order(Ascending)', Locked = true;
        InsufficientReadPermErr: Label 'You do not have sufficient permissions to read from the table.';
        EmitTelemetry: Boolean;
        CDMDataFormat: Enum "RSMUS Data Export Format";

    [TryFunction]
    local procedure TryExportTableData(TableID: Integer; ExportFormat: Enum "RSMUS Data Export Format"; StripEscapedDblQuotes: Boolean; TestRecordTime: DateTime; var rsmusCommunication: Codeunit "RSMUS Communication";
        var UpdatedLastTimeStamp: BigInteger; var DeletedLastEntryNo: BigInteger;
        var EntityJsonNeedsUpdate: Boolean; var ManifestJsonsNeedsUpdate: Boolean)
    var
        rsmusCommunicationDeletions: Codeunit "RSMUS Communication";
        FieldIdList: List of [Integer];
    begin
        FieldIdList := CreateFieldListForTable(TableID);

        // first export the upserts
        rsmusCommunication.Init(TableID, ExportFormat, StripEscapedDblQuotes, FieldIdList, TestRecordTime, UpdatedLastTimeStamp, EmitTelemetry);
        rsmusCommunication.CheckEntity(CDMDataFormat, EntityJsonNeedsUpdate, ManifestJsonsNeedsUpdate);
        ExportTableUpdates(TableID, FieldIdList, rsmusCommunication, UpdatedLastTimeStamp, CDMDataFormat);

        // then export the deletes
        rsmusCommunicationDeletions.Init(TableID, ExportFormat, StripEscapedDblQuotes, FieldIdList, TestRecordTime, DeletedLastEntryNo, EmitTelemetry);
        // entity has been already checked above
        ExportTableDeletes(TableID, rsmusCommunicationDeletions, DeletedLastEntryNo);
    end;

    procedure UpdatedRecordsExist(TableID: Integer; UpdatedLastTimeStamp: BigInteger): Boolean
    var
        rsmusSeekData: Report "RSMUS Seek Data";
        Rec: RecordRef;
        TimeStampField: FieldRef;
    begin
        SetFilterForUpdates(TableID, UpdatedLastTimeStamp, Rec, TimeStampField);
        exit(rsmusSeekData.RecordsExist(Rec));
    end;

    local procedure SetFilterForUpdates(TableID: Integer; UpdatedLastTimeStamp: BigInteger; var Rec: RecordRef; var TimeStampField: FieldRef)
    begin
        Rec.Open(TableID);
        Rec.SetView(TimestampAscendingSortViewTxt);
        TimeStampField := Rec.Field(0); // 0 is the TimeStamp field
        TimeStampField.SetFilter('>%1', UpdatedLastTimestamp);
    end;

    local procedure ExportTableUpdates(TableID: Integer; FieldIdList: List of [Integer]; rsmusCommunication: Codeunit "RSMUS Communication"; var UpdatedLastTimeStamp: BigInteger; ExportFormat: Enum "RSMUS Data Export Format")
    var
        rsmusSeekData: Report "RSMUS Seek Data";
        rsmusExecution: Codeunit "RSMUS Execution";
        Rec: RecordRef;
        TimeStampField: FieldRef;
        Field: FieldRef;
        CustomDimensions: Dictionary of [Text, Text];
        TableCaption: Text;
        EntityCount: Text;
        FlushedTimeStamp: BigInteger;
        FieldId: Integer;
        SystemCreatedAt: DateTime;
    begin
        SetFilterForUpdates(TableID, UpdatedLastTimeStamp, Rec, TimeStampField);

        foreach FieldId in FieldIdList do
            Rec.AddLoadFields(FieldID);

        if not Rec.ReadPermission() then
            Error(InsufficientReadPermErr);

        if rsmusSeekData.FindRecords(Rec) then begin
            if EmitTelemetry then begin
                TableCaption := Rec.Caption();
                EntityCount := Format(Rec.Count());
                CustomDimensions.Add('Entity', TableCaption);
                CustomDimensions.Add('Entity Count', EntityCount);
                rsmusExecution.Log('ADLSE-021', 'Updated records found', Verbosity::Normal, Dataclassification::ToBeClassified, CustomDimensions);
            end;

            repeat
                // Records created before SystemCreatedAt field was introduced, have null values. Initialize with 01 Jan 1900
                Field := Rec.Field(Rec.SystemCreatedAtNo());
                SystemCreatedAt := Field.Value();
                if SystemCreatedAt = 0DT then
                    Field.Value(CreateDateTime(DMY2Date(1, 1, 1900), 0T));

                if rsmusCommunication.TryCollectAndSendRecord(Rec, false, TimeStampField.Value(), FlushedTimeStamp, ExportFormat) then
                    UpdatedLastTimeStamp := FlushedTimeStamp
                else
                    Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
            until Rec.Next() = 0;

            if rsmusCommunication.TryFinish(FlushedTimeStamp) then
                UpdatedLastTimeStamp := FlushedTimeStamp
            else
                Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
        end;
        if EmitTelemetry then
            rsmusExecution.Log('ADLSE-009', 'Updated records exported', Verbosity::Verbose, Dataclassification::ToBeClassified);
    end;

    procedure DeletedRecordsExist(TableID: Integer; DeletedLastEntryNo: BigInteger): Boolean
    var
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
        rsmusSeekData: Report "RSMUS Seek Data";
    begin
        SetFilterForDeletes(TableID, DeletedLastEntryNo, rsmusDeletedRecord);
        exit(rsmusSeekData.RecordsExist(rsmusDeletedRecord));
    end;

    local procedure SetFilterForDeletes(TableID: Integer; DeletedLastEntryNo: BigInteger; var rsmusDeletedRecord: Record "RSMUS Deleted Record")
    begin
        rsmusDeletedRecord.SetView(TimestampAscendingSortViewTxt);
        rsmusDeletedRecord.SetRange("Table ID", TableID);
        rsmusDeletedRecord.SetFilter("Entry No.", '>%1', DeletedLastEntryNo);
    end;

    local procedure ExportTableDeletes(TableID: Integer; rsmusCommunication: Codeunit "RSMUS Communication"; var DeletedLastEntryNo: BigInteger)
    var
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
        rsmusSeekData: Report "RSMUS Seek Data";
        rsmusUtil: Codeunit "RSMUS Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        Rec: RecordRef;
        CustomDimensions: Dictionary of [Text, Text];
        TableCaption: Text;
        EntityCount: Text;
        FlushedTimeStamp: BigInteger;
    begin
        SetFilterForDeletes(TableID, DeletedLastEntryNo, rsmusDeletedRecord);

        if rsmusSeekData.FindRecords(rsmusDeletedRecord) then begin
            Rec.Open(rsmusDeletedRecord."Table ID");

            if EmitTelemetry then begin
                TableCaption := Rec.Caption();
                EntityCount := Format(rsmusDeletedRecord.Count());
                CustomDimensions.Add('Entity', TableCaption);
                CustomDimensions.Add('Entity Count', EntityCount);
                rsmusExecution.Log('ADLSE-010', 'Deleted records found', Verbosity::Normal, DataClassification::SystemMetadata, CustomDimensions);
            end;

            repeat
                rsmusUtil.CreateFakeRecordForDeletedAction(rsmusDeletedRecord, Rec);
                if rsmusCommunication.TryCollectAndSendRecord(Rec, true, rsmusDeletedRecord."Entry No.", FlushedTimeStamp, CDMDataFormat) then
                    DeletedLastEntryNo := FlushedTimeStamp
                else
                    Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
            until rsmusDeletedRecord.Next() = 0;

            if rsmusCommunication.TryFinish(FlushedTimeStamp) then
                DeletedLastEntryNo := FlushedTimeStamp
            else
                Error('%1%2', GetLastErrorText(), GetLastErrorCallStack());
        end;
        if EmitTelemetry then
            rsmusExecution.Log('ADLSE-011', 'Deleted records exported', Verbosity::Normal, DataClassification::ToBeClassified, CustomDimensions);
    end;

    local procedure CreateFieldListForTable(TableID: Integer) FieldIdList: List of [Integer]
    var
        rsmusField: Record "RSMUS Field";
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        rsmusField.SetRange("Table ID", TableID);
        rsmusField.SetRange(Enabled, true);
        if rsmusField.FindSet() then
            repeat
                FieldIdList.Add(rsmusField."Field ID");
            until rsmusField.Next() = 0;
        rsmusUtil.AddSystemFields(FieldIdList);
    end;

    local procedure SetStateFinished(var rsmusTable: Record "RSMUS Table")
    var
        rsmusRun: Record "RSMUS Runs Log";
        rsmusCurrentSession: Record "RSMUS Current Session";
        rsmusSessionManager: Codeunit "RSMUS Session Manager";
    begin
        rsmusRun.RegisterEnded(rsmusTable."Table ID", EmitTelemetry);
        rsmusCurrentSession.Stop(rsmusTable."Table ID", EmitTelemetry);
        Commit();

        // This export session is soon going to end. Start up a new one from 
        // the stored list of pending tables to export.
        // Note that initially as many export sessions, as is allowed per the 
        // operation limits, are spawned up. The following line continously 
        // add to the number of sessions by consuming the pending backlog, thus
        // prolonging the time to finish an export batch. If this is a concern, 
        // consider commenting out the line below so no futher sessions are 
        // spawned when the active ones end. This may result in some table 
        // exports being skipped. But they may become active in the next export 
        // batch. 
        rsmusSessionManager.StartExportFromPendingTables();
    end;
}
