// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
table 82661 "RSMUS Table"
{
    Access = Internal;
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Editable = false;
            Caption = 'Table ID';
        }
        field(2; State; Enum "RSMUS State")
        {
            Caption = 'State';
            ObsoleteReason = 'Use ADLSE Run table instead';
            ObsoleteTag = '1.2.2.0';
            ObsoleteState = Removed;
        }
        field(3; Enabled; Boolean)
        {
            Editable = false;
            Caption = 'Enabled';

            trigger OnValidate()
            begin
                if Rec.Enabled then
                    CheckExportingOnlyValidFields();
            end;
        }
        field(5; LastError; Text[2048])
        {
            Editable = false;
            Caption = 'Last error';
            ObsoleteReason = 'Use ADLSE Run table instead';
            ObsoleteTag = '1.2.2.0';
            ObsoleteState = Removed;
        }
    }

    keys
    {
        key(Key1; "Table ID")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        rsmusSetup: Record "RSMUS Setup";
    begin
        rsmusSetup.CheckNoSimultaneousExportsAllowed();

        CheckTableOfTypeNormal(Rec."Table ID");
    end;

    trigger OnDelete()
    var
        rsmusSetup: Record "RSMUS Setup";
        rsmusTableField: Record "RSMUS Field";
        rsmusTableLastTimestamp: Record "RSMUS Table Tracking";
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
    begin
        rsmusSetup.CheckNoSimultaneousExportsAllowed();

        rsmusTableField.SetRange("Table ID", Rec."Table ID");
        rsmusTableField.DeleteAll();

        rsmusDeletedRecord.SetRange("Table ID", Rec."Table ID");
        rsmusDeletedRecord.DeleteAll();

        rsmusTableLastTimestamp.SetRange("Table ID", Rec."Table ID");
        rsmusTableLastTimestamp.DeleteAll();
    end;

    trigger OnModify()
    var
        rsmusSetup: Record "RSMUS Setup";
    begin
        rsmusSetup.CheckNoSimultaneousExportsAllowed();

        CheckNotExporting();
    end;

    var
        TableNotNormalErr: Label 'Table %1 is not a normal table.', Comment = '%1: caption of table';
        TableExportingDataErr: Label 'Data is being executed for table %1. Please wait for the export to finish before making changes.', Comment = '%1: table caption';
        TableCannotBeExportedErr: Label 'The table %1 cannot be exported because of the following error. \%2', Comment = '%1: Table ID, %2: error text';
        TablesResetTxt: Label '%1 table(s) were reset.', Comment = '%1 = number of tables that were reset';

    procedure FieldsChosen(): Integer
    var
        rsmusField: Record "RSMUS Field";
    begin
        rsmusField.SetRange("Table ID", Rec."Table ID");
        rsmusField.SetRange(Enabled, true);
        exit(rsmusField.Count());
    end;

    procedure Add(TableID: Integer)
    begin
        if not CheckTableCanBeExportedFrom(TableID) then
            Error(TableCannotBeExportedErr, TableID, GetLastErrorText());
        Rec.Init();
        Rec."Table ID" := TableID;
        Rec.Enabled := true;
        Rec.Insert(true);
    end;

    [TryFunction]
    local procedure CheckTableCanBeExportedFrom(TableID: Integer)
    var
        RecordRef: RecordRef;
    begin
        ClearLastError();
        RecordRef.Open(TableID); // proves the table exists and can be opened
    end;

    local procedure CheckTableOfTypeNormal(TableID: Integer)
    var
        TableMetadata: Record "Table Metadata";
        rsmusUtil: Codeunit "RSMUS Util";
        TableCaption: Text;
    begin
        TableCaption := rsmusUtil.GetTableCaption(TableID);

        TableMetadata.SetRange(ID, TableID);
        TableMetadata.FindFirst();

        if TableMetadata.TableType <> TableMetadata.TableType::Normal then
            Error(TableNotNormalErr, TableCaption);
    end;

    procedure CheckNotExporting()
    var
        rsmusUtil: Codeunit "RSMUS Util";
    begin
        if GetLastRunState() = "RSMUS Run State"::InProcess then
            Error(TableExportingDataErr, rsmusUtil.GetTableCaption(Rec."Table ID"));
    end;

    local procedure GetLastRunState(): enum "RSMUS Run State"
    var
        rsmusRun: Record "RSMUS Runs Log";
        LastState: enum "RSMUS Run State";
        LastStarted: DateTime;
        LastErrorText: Text[2048];
    begin
        rsmusRun.GetLastRunDetails(Rec."Table ID", LastState, LastStarted, LastErrorText);
        exit(LastState);
    end;

    procedure ResetSelected()
    var
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
        rsmusTableLastTimestamp: Record "RSMUS Table Tracking";
        Counter: Integer;
    begin
        if Rec.FindSet(true) then
            repeat
                Rec.Enabled := true;
                Rec.Modify();

                rsmusTableLastTimestamp.SaveUpdatedLastTimestamp(Rec."Table ID", 0);
                rsmusTableLastTimestamp.SaveDeletedLastEntryNo(Rec."Table ID", 0);

                rsmusDeletedRecord.SetRange("Table ID", Rec."Table ID");
                rsmusDeletedRecord.DeleteAll();
                Counter += 1;
            until Rec.Next() = 0;
        Message(TablesResetTxt, Counter);
    end;

    local procedure CheckExportingOnlyValidFields()
    var
        rsmusField: Record "RSMUS Field";
        Field: Record Field;
        rsmusSetup: Codeunit "RSMUS Setup";
    begin
        rsmusField.SetRange("Table ID", Rec."Table ID");
        rsmusField.SetRange(Enabled, true);
        if rsmusField.FindSet() then
            repeat
                Field.Get(rsmusField."Table ID", rsmusField."Field ID");
                rsmusSetup.CheckFieldCanBeExported(Field);
            until rsmusField.Next() = 0;
    end;

    procedure ListInvalidFieldsBeingExported() FieldList: List of [Text]
    var
        rsmusField: Record "RSMUS Field";
        rsmusSetup: Codeunit "RSMUS Setup";
        rsmusUtil: Codeunit "RSMUS Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        rsmusField.SetRange("Table ID", Rec."Table ID");
        rsmusField.SetRange(Enabled, true);
        if rsmusField.FindSet() then
            repeat
                if not rsmusSetup.CanFieldBeExported(rsmusField."Table ID", rsmusField."Field ID") then begin
                    rsmusField.CalcFields(FieldCaption);
                    FieldList.Add(rsmusField.FieldCaption);
                end;
            until rsmusField.Next() = 0;

        CustomDimensions.Add('Entity', rsmusUtil.GetTableCaption(Rec."Table ID"));
        CustomDimensions.Add('ListOfFields', rsmusUtil.Concatenate(FieldList));
        // ADLSEExecution.Log('ADLSE-029', 'The following invalid fields are configured to be exported from the table.',
        //     Verbosity::Warning, CustomDimensions);
    end;
}