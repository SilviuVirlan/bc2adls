// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
codeunit 82671 "RSMUS Installer"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerDatabase()
    begin
        DisableTablesExportingInvalidFields();
    end;

    trigger OnInstallAppPerCompany()
    begin
        AddAllowedTables();
    end;

    procedure AddAllowedTables()
    var
        rsmusRun: Record "RSMUS Runs Log";
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
    begin
        RetenPolAllowedTables.AddAllowedTable(Database::"RSMUS Runs Log", rsmusRun.FieldNo(SystemModifiedAt));
    end;

    procedure ListInvalidFieldsBeingExported() InvalidFieldsMap: Dictionary of [Integer, List of [Text]]
    var
        rsmusTable: Record "RSMUS Table";
        InvalidFields: List of [Text];
    begin
        // find the tables which export fields that have now been obsoleted or are invalid
        rsmusTable.SetRange(Enabled, true);
        if rsmusTable.FindSet() then
            repeat
                InvalidFields := rsmusTable.ListInvalidFieldsBeingExported();
                if InvalidFields.Count() > 0 then
                    InvalidFieldsMap.Add(rsmusTable."Table ID", InvalidFields);
            until rsmusTable.Next() = 0;
    end;

    local procedure DisableTablesExportingInvalidFields()
    var
        rsmusTable: Record "RSMUS Table";
        rsmusUtil: Codeunit "RSMUS Util";
        rsmusExecution: Codeunit "RSMUS Execution";
        InvalidFieldsMap: Dictionary of [Integer, List of [Text]];
        CustomDimensions: Dictionary of [Text, Text];
        TableID: Integer;
    begin
        InvalidFieldsMap := ListInvalidFieldsBeingExported();
        foreach TableID in InvalidFieldsMap.Keys() do begin
            rsmusTable.Get(TableID);
            rsmusTable.Enabled := false;
            rsmusTable.Modify();

            Clear(CustomDimensions);
            CustomDimensions.Add('Entity', rsmusUtil.GetTableCaption(TableID));
            CustomDimensions.Add('ListOfInvalidFields', rsmusUtil.Concatenate(InvalidFieldsMap.Get(TableID)));
            rsmusExecution.Log('ADLSE-31', 'Table is disabled for export because it exports invalid fields.', Verbosity::Warning, DataClassification::ToBeClassified, CustomDimensions);
        end;
    end;
}