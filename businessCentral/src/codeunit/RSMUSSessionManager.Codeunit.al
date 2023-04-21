// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82670 "RSMUS Session Manager"
{
    Access = Internal;

    var
        PendingTablesKeyTxt: Label 'Pending', Locked = true;
        ConcatendatedStringLbl: Label '%1,%2', Locked = true;

    procedure Init()
    begin
        SavePendingTables('');
    end;

    procedure StartExport(TableID: Integer; EmitTelemetry: Boolean): Boolean
    begin
        // if the last run failed, ensure that you run again, even though there may be no data differences.
        exit(StartExport(TableID, false, LastRunFailed(TableID, EmitTelemetry), EmitTelemetry));
    end;

    local procedure StartExportFromPending(TableID: Integer; EmitTelemetry: Boolean): Boolean
    begin
        StartExport(TableID, true, false, EmitTelemetry);
    end;

    local procedure StartExport(TableID: Integer; ExportWasPending: Boolean; ForceExport: Boolean; EmitTelemetry: Boolean) Started: Boolean
    var
        rsmusTable: Record "RSMUS Table";
        rsmusExecution: Codeunit "RSMUS Execution";
        rsmusUtil: Codeunit "RSMUS Util";
        CustomDimensions: Dictionary of [Text, Text];
        NewSessionID: Integer;
    begin
        if ForceExport or DataChangesExist(TableID) then begin
            rsmusTable.Get(TableID);
            Started := Session.StartSession(NewSessionID, Codeunit::"RSMUS Execute", CompanyName(), rsmusTable);
            CustomDimensions.Add('Entity', rsmusUtil.GetTableCaption(TableID));
            CustomDimensions.Add('ExportWasPending', Format(ExportWasPending));
            if Started then begin
                CustomDimensions.Add('SessionId', Format(NewSessionID));
                if EmitTelemetry then
                    rsmusExecution.Log('ADLSE-002', 'Export session created', Verbosity::Normal, DataClassification::ToBeClassified, CustomDimensions);

                if ExportWasPending then
                    RemoveFromPendingTables(TableID); // remove because the export session was started
            end else begin
                if EmitTelemetry then
                    rsmusExecution.Log('ADLSE-025', 'Session.StartSession() failed', Verbosity::Warning, DataClassification::ToBeClassified, CustomDimensions);

                if not ExportWasPending then
                    PushToPendingTables(TableID);
            end;
        end else begin
            if ExportWasPending then
                RemoveFromPendingTables(TableID); // remove because a previous export may have successful

            if EmitTelemetry then begin
                CustomDimensions.Add('Entity', rsmusUtil.GetTableCaption(TableID));
                rsmusExecution.Log('ADLSE-024', 'No changes to be exported.', Verbosity::Normal, DataClassification::ToBeClassified, CustomDimensions);
            end;
        end;
    end;

    local procedure DataChangesExist(TableID: Integer): Boolean
    var
        rsmusTableLastTimestamp: Record "RSMUS Table Tracking";
        rsmusExecute: Codeunit "RSMUS Execute";
        UpdatedLastTimestamp: BigInteger;
        DeletedLastEntryNo: BigInteger;
    begin
        UpdatedLastTimestamp := rsmusTableLastTimestamp.GetUpdatedLastTimestamp(TableID);
        DeletedLastEntryNo := rsmusTableLastTimestamp.GetDeletedLastEntryNo(TableID);

        if rsmusExecute.UpdatedRecordsExist(TableID, UpdatedLastTimestamp) then
            exit(true);
        if rsmusExecute.DeletedRecordsExist(TableID, DeletedLastEntryNo) then
            exit(true);
    end;

    local procedure LastRunFailed(TableID: Integer; EmitTelemetry: Boolean) Result: Boolean
    var
        rsmusRun: Record "RSMUS Runs Log";
        rsmusUtil: Codeunit "RSMUS Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        CustomDimensions: Dictionary of [Text, Text];
        Status: Enum "RSMUS Run State";
        StartedAt: DateTime;
        Error: Text[2048];
    begin
        rsmusRun.GetLastRunDetails(TableID, Status, StartedAt, Error);
        //sv
        //Result := Status = "RSMUS Run State"::Failed;
        Result := (Status = "RSMUS Run State"::Failed) or (Status = "RSMUS Run State"::None);
        //sv.end
        if Result and EmitTelemetry then begin
            CustomDimensions.Add('Entity', rsmusUtil.GetTableCaption(TableID));
            rsmusExecution.Log('ADLSE-027', 'Last run failed.', Verbosity::Verbose, DataClassification::ToBeClassified, CustomDimensions);
        end;
    end;

    procedure StartExportFromPendingTables()
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusExecution: Codeunit "RSMUS Execution";
        CustomDimensions: Dictionary of [Text, Text];
        TableID: Integer;
    begin
        rsmusSetup.GetSingleton();

        if rsmusSetup."Emit telemetry" then begin
            CustomDimensions.Add('PendingTables', Concatenate(GetPendingTablesList()));
            rsmusExecution.Log('ADLSE-026', 'Export from pending tables starting', Verbosity::Verbose, DataClassification::ToBeClassified, CustomDimensions);
        end;

        // One session freed up. create session from queue
        if GetFromPendingTables(TableID) then
            StartExportFromPending(TableID, rsmusSetup."Emit telemetry");
    end;

    local procedure GetFromPendingTables(var TableID: Integer): Boolean
    var
        Tables: List of [Integer];
    begin
        Tables := GetPendingTablesList();
        exit(Tables.Get(1, TableID));
    end;

    local procedure PushToPendingTables(TableID: Integer)
    var
        Tables: List of [Integer];
    begin
        Tables := GetPendingTablesList();
        if not Tables.Contains(TableID) then begin
            Tables.Add(TableID);
            SavePendingTables(Concatenate(Tables));
        end;
    end;

    local procedure RemoveFromPendingTables(TableID: Integer): Boolean
    var
        Tables: List of [Integer];
    begin
        Tables := GetPendingTablesList();
        if Tables.Remove(TableID) then
            SavePendingTables(Concatenate(Tables));
    end;

    local procedure GetPendingTablesList(): List of [Integer]
    var
        Result: Text;
    begin
        IsolatedStorage.Get(PendingTablesKeyTxt, DataScope::Company, Result);
        exit(DeConcatenate(Result));
    end;

    local procedure Concatenate(Values: List of [Integer]) Result: Text
    var
        Value: Integer;
    begin
        foreach Value in Values do
            if Result = '' then
                Result := Format(Value, 0, 9)
            else
                Result := StrSubstNo(ConcatendatedStringLbl, Result, Value);
    end;

    local procedure DeConcatenate(CommaSeperatedText: Text) Values: List of [Integer]
    var
        TextValues: List of [Text];
        ValueText: Text;
        ValueInt: Integer;
    begin
        TextValues := CommaSeperatedText.Split(',');
        foreach ValueText in TextValues do
            if Evaluate(ValueInt, ValueText) then
                Values.Add(ValueInt);
    end;

    local procedure SavePendingTables(Value: Text)
    begin
        if IsolatedStorage.Set(PendingTablesKeyTxt, Value, DataScope::Company) then
            Commit(); // changing isolated storage triggers a write transaction            
    end;
}