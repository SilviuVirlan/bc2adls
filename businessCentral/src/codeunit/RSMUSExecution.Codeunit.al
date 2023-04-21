// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82669 "RSMUS Execution"
{
    Access = Internal;

    trigger OnRun()
    begin
        StartExport();
    end;

    var
        EmitTelemetry: Boolean;
        ExportStartedTxt: Label 'Data export started for %1 out of %2 tables. Please refresh this page to see the latest export state for the tables. Only those tables that either have had changes since the last export or failed to export last time have been included. The tables for which the exports could not be started have been queued up for later.', Comment = '%1 = number of tables to start the export for. %2 = total number of tables enabled for export.';
        SuccessfulStopMsg: Label 'The export process was stopped successfully.';
        TrackedDeletedRecordsRemovedMsg: Label 'Representations of deleted records that have been exported previously have been deleted.';
        JobCategoryCodeTxt: Label 'ADLSE';
        JobCategoryDescriptionTxt: Label 'Export to Azure Data Lake';
        JobScheduledTxt: Label 'The job has been scheduled. Please go to the Job Queue Entries page to locate it and make further changes.';

    procedure StartExport()
    var
        rsmusSetupRec: Record "RSMUS Setup";
        rsmusTable: Record "RSMUS Table";
        rsmusField: Record "RSMUS Field";
        rsmusCurrentSession: Record "RSMUS Current Session";
        rsmusSetup: Codeunit "RSMUS Setup";
        rsmusCommunication: Codeunit "RSMUS Communication";
        rsmusSessionManager: Codeunit "RSMUS Session Manager";
        Counter: Integer;
        Started: Integer;
    begin
        rsmusSetup.CheckSetup(rsmusSetupRec);
        EmitTelemetry := rsmusSetupRec."Emit telemetry";
        rsmusCurrentSession.CleanupSessions();
        rsmusCommunication.SetupBlobStorage();
        rsmusSessionManager.Init();

        if EmitTelemetry then
            Log('ADLSE-022', 'Starting export for all tables', Verbosity::Normal, DataClassification::ToBeClassified);
        //ADLSETable.SetRange(State, "RSMUS State"::Ready);
        if rsmusTable.FindSet(true) then
            repeat
                Counter += 1;
                rsmusField.SetRange("Table ID", rsmusTable."Table ID");
                rsmusField.SetRange(Enabled, true);
                if not rsmusField.IsEmpty() then
                    if rsmusSessionManager.StartExport(rsmusTable."Table ID", EmitTelemetry) then
                        Started += 1;
            until rsmusTable.Next() = 0;

        Message(ExportStartedTxt, Started, Counter);
        if EmitTelemetry then
            Log('ADLSE-001', StrSubstNo(ExportStartedTxt, Started, Counter), Verbosity::Normal, DataClassification::ToBeClassified);
    end;

    procedure StopExport()
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusRun: Record "RSMUS Runs Log";
        rsmusCurrentSession: Record "RSMUS Current Session";
    begin
        rsmusSetup.GetSingleton();
        if rsmusSetup."Emit telemetry" then
            Log('ADLSE-003', 'Stopping export sessions', Verbosity::Normal, DataClassification::ToBeClassified);

        rsmusCurrentSession.CancelAll();

        rsmusRun.CancelAllRuns();

        Message(SuccessfulStopMsg);
        if rsmusSetup."Emit telemetry" then
            Log('ADLSE-004', 'Stopped export sessions', Verbosity::Normal, DataClassification::ToBeClassified);
    end;

    procedure ScheduleExport()
    var
        JobQueueEntry: Record "Job Queue Entry";
        ScheduleAJob: Page "Schedule a Job";
    begin
        CreateJobQueueEntry(JobQueueEntry);
        ScheduleAJob.SetJob(JobQueueEntry);
        Commit(); // above changes go into the DB before RunModal
        if ScheduleAJob.RunModal() = Action::OK then
            Message(JobScheduledTxt);
    end;

    local procedure CreateJobQueueEntry(var JobQueueEntry: Record "Job Queue Entry")
    var
        JobQueueCategory: Record "Job Queue Category";
    begin
        JobQueueCategory.InsertRec(JobCategoryCodeTxt, JobCategoryDescriptionTxt);
        if JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"RSMUS Execution") then
            exit;
        JobQueueEntry.Init();
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Description := JobQueueCategory.Description;
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := CODEUNIT::"RSMUS Execution";
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime(); // now
        JobQueueEntry."Expiration Date/Time" := CurrentDateTime() + (7 * 24 * 60 * 60 * 1000); // 7 days from now
    end;

    procedure ClearTrackedDeletedRecords()
    var
        rsmusTable: Record "RSMUS Table";
        rsmusTableLastRowVersion: Record "RSMUS Table Tracking";
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
    begin
        rsmusTable.SetLoadFields("Table ID");
        if rsmusTable.FindSet() then
            repeat
                rsmusDeletedRecord.SetRange("Table ID", rsmusTable."Table ID");
                rsmusDeletedRecord.SetFilter("Entry No.", '<=%1', rsmusTableLastRowVersion.GetDeletedLastEntryNo(rsmusTable."Table ID"));
                rsmusDeletedRecord.DeleteAll();

                rsmusTableLastRowVersion.SaveDeletedLastEntryNo(rsmusTable."Table ID", 0);
            until rsmusTable.Next() = 0;
        Message(TrackedDeletedRecordsRemovedMsg);
    end;


    procedure ClearLastRowVersions()
    var
        ADLSETable: Record "RSMUS Table";
        ADLSESetup: Codeunit "RSMUS Setup";
    begin
        ADLSETable.FindSet(false);
        repeat
            ADLSESetup.Reset(ADLSETable);
        until ADLSETable.Next() = 0;
    end;

    internal procedure Log(EventId: Text; Message: Text; Verbosity: Verbosity; DataClassification: DataClassification)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        Log(EventId, Message, Verbosity, DataClassification, CustomDimensions);
    end;

    internal procedure Log(EventId: Text; Message: Text; Verbosity: Verbosity; DataClassification: DataClassification; CustomDimensions: Dictionary of [Text, Text])
    begin
        Session.LogMessage(EventId, Message, Verbosity, DataClassification, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::GlobalTriggerManagement, 'OnAfterGetDatabaseTableTriggerSetup', '', false, false)]
    local procedure GetDatabaseTableTriggerSetup(TableId: Integer; var OnDatabaseInsert: Boolean; var OnDatabaseModify: Boolean; var OnDatabaseDelete: Boolean; var OnDatabaseRename: Boolean)
    var
        rsmusTableLastRowVersion: Record "RSMUS Table Tracking";
    begin
        if CompanyName() = '' then
            exit;

        // track deletes only if at least one export has been made for that table
        if rsmusTableLastRowVersion.ExistsUpdatedLastTimestamp(TableId) then
            OnDatabaseDelete := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::GlobalTriggerManagement, 'OnAfterOnDatabaseDelete', '', false, false)]
    local procedure OnAfterOnDatabaseDelete(RecRef: RecordRef)
    var
        rsmusTableLastRowVersion: Record "RSMUS Table Tracking";
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
    begin
        // exit function for tables that you do not wish to sync deletes for
        // you should also consider not registering for deletes for the table in the function GetDatabaseTableTriggerSetup above.
        // if RecRef.Number = Database::"G/L Entry" then
        //     exit;

        // check if table is to be tracked.
        if not rsmusTableLastRowVersion.ExistsUpdatedLastTimestamp(RecRef.Number) then
            exit;

        rsmusDeletedRecord.TrackDeletedRecord(RecRef);

        rsmusTableLastRowVersion.SubtractDeleteFromRowCount(RecRef.Number);//sv
    end;
}