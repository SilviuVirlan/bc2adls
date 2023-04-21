// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82660 "RSMUS Setup"
{
    Access = Internal;

    var
        FieldClassNotSupportedErr: Label 'The field %1 of class %2 is not supported.', Comment = '%1 = field name, %2 = field class';
        SelectTableLbl: Label 'Select the tables to be exported';
        FieldObsoleteNotSupportedErr: Label 'The field %1 is obsolete', Comment = '%1 = field name';
        FieldDisabledNotSupportedErr: Label 'The field %1 is disabled', Comment = '%1 = field name';

    procedure AddTableToExport()
    var
        AllObjWithCaption: Record AllObjWithCaption;
        rsmusTable: Record "RSMUS Table";
        AllObjectsWithCaption: Page "All Objects with Caption";
    begin
        Commit();
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);

        AllObjectsWithCaption.Caption(SelectTableLbl);
        AllObjectsWithCaption.SetTableView(AllObjWithCaption);
        AllObjectsWithCaption.LookupMode(true);
        if AllObjectsWithCaption.RunModal() = Action::LookupOK then begin
            AllObjectsWithCaption.SetSelectionFilter(AllObjWithCaption);
            if AllObjWithCaption.FindSet() then
                repeat
                    rsmusTable.Add(AllObjWithCaption."Object ID");
                until AllObjWithCaption.Next() = 0;
        end;
    end;

    procedure ChooseFieldsToExport(rsmusTable: Record "RSMUS Table")
    var
        rsmusField: Record "RSMUS Field";
    begin
        rsmusField.SetRange("Table ID", rsmusTable."Table ID");
        rsmusField.InsertForTable(rsmusTable);
        Commit(); // changes made to the field table go into the database before RunModal is called
        Page.RunModal(Page::"RSMUS Setup Fields", rsmusField, rsmusField.Enabled);
    end;

    procedure CanFieldBeExported(TableID: Integer; FieldID: Integer): Boolean
    var
        Field: Record Field;
    begin
        if not Field.Get(TableID, FieldID) then
            exit(false);
        exit(CheckFieldCanBeExported(Field, false));
    end;

    procedure CheckFieldCanBeExported(Field: Record Field)
    begin
        CheckFieldCanBeExported(Field, true);
    end;

    local procedure CheckFieldCanBeExported(Field: Record Field; RaiseError: Boolean): Boolean
    begin
        if Field.Class <> Field.Class::Normal then begin
            if RaiseError then
                Error(FieldClassNotSupportedErr, Field."Field Caption", Field.Class);
            exit(false);
        end;
        if Field.ObsoleteState = Field.ObsoleteState::Removed then begin
            if RaiseError then
                Error(FieldObsoleteNotSupportedErr, Field."Field Caption");
            exit(false);
        end;
        if not Field.Enabled then begin
            if RaiseError then
                Error(FieldDisabledNotSupportedErr, Field."Field Caption");
            exit(false);
        end;
        exit(true);
    end;

    procedure CheckSetup(var rsmusSetup: Record "RSMUS Setup")
    var
        rsmusCurrentSession: Record "RSMUS Current Session";
        rsmusCredentials: Codeunit "RSMUS Credentials";
    begin
        rsmusSetup.GetSingleton();
        rsmusSetup.TestField(Container);
        if not rsmusSetup."Multi- Company Export" then
            if rsmusCurrentSession.AreAnySessionsActive() then
                rsmusCurrentSession.CheckForNoActiveSessions();

        rsmusCredentials.Check();
    end;

    procedure Reset(var ADLSETable: Record "RSMUS Table")
    var
        ADLSEDeletedRecord: Record "RSMUS Deleted Record";
        ADLSETableLastRowVersion: Record "RSMUS Table Tracking";
    begin
        ADLSETableLastRowVersion.SaveUpdatedLastTimestamp(ADLSETable."Table ID", 0);
        ADLSETableLastRowVersion.SaveDeletedLastEntryNo(ADLSETable."Table ID", 0);
        //ADLSETable.Modify();

        ADLSEDeletedRecord.SetRange("Table ID", ADLSETable."Table ID");
        ADLSEDeletedRecord.DeleteAll();
    end;
}