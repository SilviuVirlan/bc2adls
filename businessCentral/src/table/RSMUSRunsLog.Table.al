// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82666 "RSMUS Runs Log"
{
    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; ID; Integer)
        {
            Editable = false;
            Caption = 'ID';
            AutoIncrement = true;
        }
        field(2; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(3; "Company Name"; Text[30])
        {
            Editable = false;
            Caption = 'Company name';
        }
        field(4; State; Enum "RSMUS Run State")
        {
            Editable = false;
            Caption = 'State';
        }
        field(5; Error; Text[2048])
        {
            Editable = false;
            Caption = 'Error';
        }
        field(6; Started; DateTime)
        {
            Editable = false;
            Caption = 'Started';
        }
        field(7; Ended; DateTime)
        {
            Editable = false;
            Caption = 'Ended';
        }
    }

    keys
    {
        key(Key1; ID)
        {
            Clustered = true;
        }
        key(Key2; "Table ID", "Company Name")
        {
        }
        key(Key3; Started)
        { // sorting key
        }
    }

    var
        ExportRunNotFoundErr: Label 'No export process running for table %1.', Comment = '%1 = caption of the table';
        ExportStoppedDueToCancelledSessionTxt: Label 'Export stopped as session was cancelled. Please check state of the export on the data lake before enabling this.';
        CouldNotUpdateExportRunStatusErr: Label 'Could not update the status of the export run for %1 to %2.', Comment = '%1: table caption, %2: New status';

    procedure GetLastRunDetails(TableID: Integer; var Status: enum "RSMUS Run State"; var StartedTime: DateTime; var ErrorIfAny: Text[2048])
    begin
        if FindLastRun(TableID) then begin
            Status := Rec.State;
            StartedTime := Rec.Started;
            ErrorIfAny := Rec.Error;
            exit;
        end;
        Status := "RSMUS Run State"::None;
        StartedTime := 0DT;
        ErrorIfAny := '';
    end;

    procedure RegisterStarted(TableID: Integer)
    begin
        Rec.Init();
        Rec."Table ID" := TableID;
        Rec."Company Name" := CopyStr(CompanyName(), 1, 30);
        Rec.State := "RSMUS Run State"::InProcess;
        Rec.Started := CurrentDateTime();
        Rec.Insert();
    end;

    procedure RegisterEnded(TableID: Integer; EmitTelemetry: Boolean)
    var
        rsmusUtil: Codeunit "RSMUS Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        CustomDimension: Dictionary of [Text, Text];
        LastErrorMessage: Text;
        LastErrorStack: Text;
    begin
        if not FindLastRun(TableID) then begin
            rsmusExecution.Log('ADLSE-034', StrSubstNo(ExportRunNotFoundErr, rsmusUtil.GetTableCaption(TableID)), Verbosity::Error, DataClassification::ToBeClassified);
            exit;
        end;
        if Rec.State <> "RSMUS Run State"::InProcess then
            exit;
        LastErrorMessage := GetLastErrorText();
        if LastErrorMessage <> '' then begin
            LastErrorStack := GetLastErrorCallStack();
            Rec.Error := CopyStr(LastErrorMessage + LastErrorStack, 1, 2048); // 2048 is the max size of the field 
            Rec.State := "RSMUS Run State"::Failed;

            if EmitTelemetry then begin
                CustomDimension.Add('Error text', LastErrorMessage);
                CustomDimension.Add('Error stack', LastErrorStack);
                rsmusExecution.Log('rsmus-008', 'Error occured during execution', Verbosity::Error, DataClassification::ToBeClassified, CustomDimension);
            end;
            ClearLastError();
        end else
            Rec.State := "RSMUS Run State"::Success;
        Rec.Ended := CurrentDateTime();
        if not Rec.Modify() then
            rsmusExecution.Log('ADLSE-035', StrSubstNo(CouldNotUpdateExportRunStatusErr, rsmusUtil.GetTableCaption(TableID), Rec.State), Verbosity::Error, DataClassification::ToBeClassified);
    end;

    procedure CancelAllRuns()
    begin
        Rec.SetRange(State, "RSMUS Run State"::InProcess);
        Rec.ModifyAll(Ended, CurrentDateTime);
        Rec.ModifyAll(State, "RSMUS Run State"::Failed);
        Rec.ModifyAll(Error, ExportStoppedDueToCancelledSessionTxt);
    end;

    procedure OldRunsExist(): Boolean;
    begin
        CommmonFilterOnOldRuns();
        exit(not Rec.IsEmpty());
    end;

    procedure DeleteOldRuns()
    begin
        CommmonFilterOnOldRuns();
        Rec.DeleteAll();
    end;

    procedure DeleteOldRuns(TableID: Integer)
    begin
        Rec.SetRange("Table ID", TableID);
        DeleteOldRuns();
    end;

    local procedure FindLastRun(TableID: Integer) Found: Boolean
    begin
        Rec.SetCurrentKey(ID);
        Rec.Ascending(false); // order results in a way that the last one shows up first
        Rec.SetRange("Table ID", TableID);
        Rec.SetRange("Company Name", CompanyName());
        Found := Rec.FindFirst();
    end;

    local procedure CommmonFilterOnOldRuns()
    begin
        Rec.SetFilter(State, '<>%1', "RSMUS Run State"::InProcess);
        Rec.SetRange("Company Name", CompanyName());
    end;
}