// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
permissionset 82661 "RSMUS BC-2-ODS Exec"
{
    /// <summary>
    /// The permission set to be used when running the Azure Data Lake Storage export tool.
    /// </summary>
    Access = Public;
    Assignable = true;
    Caption = 'Win-Waste BC-2-ODS Process - Execute';

    Permissions = tabledata "RSMUS Setup" = RM,
                  tabledata "RSMUS Table" = RM,
                  tabledata "RSMUS Field" = R,
                  tabledata "RSMUS Deleted Record" = R,
                  tabledata "RSMUS Current Session" = RIMD,
                  tabledata "RSMUS Table Tracking" = RIMD,
                  tabledata "RSMUS Runs Log" = RIMD,
                  tabledata "RSMUS Detailed Runs Log" = RIMD;
}