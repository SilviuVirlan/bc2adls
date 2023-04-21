// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82664 "RSMUS Table Tracking"
{
    /// <summary>
    /// Keeps track of the last exported timestamps of different tables.
    /// <remarks>This table is not per company table as some of the tables it represents may not be data per company. Company name field has been added to differentiate them.</remarks>
    /// </summary>

    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; "Company Name"; Text[30])
        {
            Editable = false;
            Caption = 'Company name';
            TableRelation = Company.Name;
        }
        field(2; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
            TableRelation = "RSMUS Table"."Table ID";
        }
        field(3; "Updated Last Timestamp"; BigInteger)
        {
            Editable = false;
            Caption = 'Last timestamp exported for an updated record';
        }
        field(4; "Deleted Last Entry No."; BigInteger)
        {
            Editable = false;
            Caption = 'Entry no. of the last deleted record';
        }
        field(5; "Updated Last Record Time"; DateTime)
        {
            Editable = false;
            Caption = 'Last record time exported for an upserted record.';
        }
        field(6; RowCount; Integer)
        {
            Editable = false;
            Caption = 'Calculated Row Count';
            AutoFormatType = 1;
            AutoFormatExpression = '<precision,0:0><standard format,0>';
        }
    }

    keys
    {
        key(Key1; "Company Name", "Table ID")
        {
            Clustered = true;
        }
    }

    var
        SaveUpsertLastTimestampFailedErr: Label 'Could not save the last time stamp for the upserts on table %1.', Comment = '%1: table caption';
        SaveDeletionLastTimestampFailedErr: Label 'Could not save the last time stamp for the deletions on table %1.', Comment = '%1: table caption';

    procedure ExistsUpdatedLastTimestamp(TableID: Integer): Boolean
    begin
        exit(Rec.Get(GetCompanyNameToLookFor(TableID), TableID));
    end;

    procedure GetUpdatedLastTimestamp(TableID: Integer): BigInteger
    begin
        if ExistsUpdatedLastTimestamp(TableID) then
            exit(Rec."Updated Last Timestamp");
    end;

    procedure GetDeletedLastEntryNo(TableID: Integer): BigInteger
    begin
        if Rec.Get(GetCompanyNameToLookFor(TableID), TableID) then
            exit(Rec."Deleted Last Entry No.");
    end;

    procedure GetUpdatedLastRecordTime(TableID: Integer): DateTime
    begin
        if ExistsUpdatedLastTimestamp(TableID) then
            exit(Rec."Updated Last Record Time");
    end;

    procedure TrySaveUpdatedLastTimestamp(TableID: Integer; Timestamp: BigInteger; EmitTelemetry: Boolean) Result: Boolean
    var
        rsmusExecution: Codeunit "RSMUS Execution";
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        Result := RecordUpsertLastTimestamp(TableID, Timestamp);
        if EmitTelemetry and (not Result) then
            rsmusExecution.Log('rsmus-032', StrSubstNo(SaveUpsertLastTimestampFailedErr, rsmusUtil.GetTableCaption(TableID)), Verbosity::Error, DataClassification::ToBeClassified);
    end;

    procedure SaveUpdatedLastTimestamp(TableID: Integer; Timestamp: BigInteger)
    var
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        if not RecordUpsertLastTimestamp(TableID, Timestamp) then
            Error(SaveUpsertLastTimestampFailedErr, rsmusUtil.GetTableCaption(TableID));
    end;

    local procedure RecordUpsertLastTimestamp(TableID: Integer; Timestamp: BigInteger): Boolean
    begin
        exit(RecordLastTimestamp(TableID, Timestamp, true));
    end;

    procedure TrySaveDeletedLastEntryNo(TableID: Integer; Timestamp: BigInteger; EmitTelemetry: Boolean) Result: Boolean
    var
        rsmusExecution: Codeunit "RSMUS Execution";
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        Result := RecordDeletedLastTimestamp(TableID, Timestamp);
        if EmitTelemetry and (not Result) then
            rsmusExecution.Log('rsmus-033', StrSubstNo(SaveDeletionLastTimestampFailedErr, rsmusUtil.GetTableCaption(TableID)), Verbosity::Error, DataClassification::ToBeClassified);
    end;

    procedure SaveDeletedLastEntryNo(TableID: Integer; Timestamp: BigInteger)
    var
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        if not RecordDeletedLastTimestamp(TableID, Timestamp) then
            Error(SaveDeletionLastTimestampFailedErr, rsmusUtil.GetTableCaption(TableID));
    end;

    local procedure RecordDeletedLastTimestamp(TableID: Integer; Timestamp: BigInteger): Boolean
    begin
        exit(RecordLastTimestamp(TableID, Timestamp, false));
    end;
    
    procedure SubtractDeleteFromRowCount(TableID: Integer)
    var
        Company: Text;
    begin
        Company := GetCompanyNameToLookFor(TableID);
        if Rec.Get(Company, TableID) then begin
            Rec.RowCount -= 1;
            Rec.Modify();
        end;
    end;
    
    local procedure RecordLastTimestamp(TableID: Integer; Timestamp: BigInteger; Upsert: Boolean): Boolean
    var
        Company: Text;
    begin
        Company := GetCompanyNameToLookFor(TableID);
        if Rec.Get(Company, TableID) then begin
            ChangeLastTimestamp(Timestamp, Upsert);
            exit(Rec.Modify());
        end else begin
            Rec.Init();
            Rec."Company Name" := CopyStr(Company, 1, 30);
            Rec."Table ID" := TableID;
            ChangeLastTimestamp(Timestamp, Upsert);
            exit(Rec.Insert());
        end;
    end;

    local procedure ChangeLastTimestamp(Timestamp: BigInteger; Upsert: Boolean)
    begin
        if Upsert then
            Rec."Updated Last Timestamp" := Timestamp
        else
            Rec."Deleted Last Entry No." := Timestamp;
    end;

    local procedure GetCompanyNameToLookFor(TableID: Integer): Text
    var
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        if rsmusUtil.IsTablePerCompany(TableID) then
            exit(CurrentCompany());
        // else it remains blank
    end;
}