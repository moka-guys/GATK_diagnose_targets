# GATK3 

## What data are required for this app to run?

This app is only a wrapper for the GATK 3.x software, and requires that you appropriately license and obtain that software yourself.
After licensing GATK, you should have received a file with the `GenomeAnalysisTK` prefix and the `.jar` suffix, such as `GenomeAnalysisTK.jar`
or `GenomeAnalysisTK-3.4-0.jar`. Place that file anywhere inside the project where this app will run. The app will search your
project for a file matching the pattern `GenomeAnalysisTK*.jar` and use it.
