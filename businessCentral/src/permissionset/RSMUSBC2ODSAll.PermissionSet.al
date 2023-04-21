// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
permissionset 82662 "RSMUS BC-2-ODS - All"
{
    /// <summary>
    /// The permission set used to register the deletion of any record, so that the information of it being deleted can be conveyed to the Azure data lake.
    /// </summary>
    Access = Public;
    Assignable = true;
    Caption = 'Win-Waste BC-2-ODS Process - Track Deletions';

    Permissions = tabledata "RSMUS Deleted Record" = I,
                  tabledata "RSMUS Table Tracking" = RM;

}