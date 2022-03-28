## dataset catalogue

Constructing a catalogue of CAP datasets in EDI was considerably easier for this DMP compared to the previous effort thanks to the EDIUtils package. Building the catalogue consists of two steps, (1) harvesting the data from EDI, facilitated in `harvest_datasets.R`, and (2) constructing the table with appropriate formatting as a Word document, detailed in (`cap_datasets.Rmd`).

- note that there are two approaches to harvesting data from EDI: by user and by scope, the latter being the appropriate method for this purpose
- I tried many tools but `flextable` was the only workable (brilliant, in fact) solution to constructing the catalogue in Word as needed/desired

## the DMP

The DMP drew heavily from the CAP IV DMP and materials developed for the mid-term site review (fall 2020). `cap_v_dmp.md` is the first-pass at constructing the DMP. This was converted to Word as `cap_v_dmp.docx` and passed to D. Childers. All subsequent editing (though minimal) was addressed in Word with `cap_v_dmp_dlc.docx` being the final version that was sent from S. Earl to D. Childers. D. Childers and/or other members of the writing team almost certainly made further edits so the version(s) included in the repository likely differs, at least slightly, from the version that was ultimately included in the proposal.
