#! /usr/bin/gawk -f
# Reduce the combinations of neutrino flavors and target isotopes in a
# GENIE gxspl XML spline file.
#    gawk -f reduce_gxspl.awk gxspl-big.xml > gxspl-small.xml
#
# This only limits what is allowed; if a combination isn't in the
# input file it won't magically appear in the output
#
BEGIN {
  doout=1; keep=1;
  nlines=0; maxlines=0; # set non-zero maxlines only for testing puroses
  # whether to keep each species of neutrino
  nukeep[12] = 1;   #
  nukeep[-12] = 1;   #
  nukeep[14] = 1;   #
  nukeep[-14] = 1;   #
  nukeep[16] = 1;   #
  nukeep[-16] = 1;   #
  # whether to keep particular isotopes
  tgtkeep[1000000010] = 1;   # free-n
  tgtkeep[1000010010] = 1;   # H1
  tgtkeep[1000010020] = 1;   # H2
  tgtkeep[1000020040] = 1;   # He4
  tgtkeep[1000040090] = 1;   # Be9
  tgtkeep[1000050110] = 1;   # B11
  tgtkeep[1000060120] = 1;   # C12
  tgtkeep[1000070140] = 1;   # N14
  tgtkeep[1000080160] = 1;   # O16
  tgtkeep[1000090190] = 1;   # F19
  tgtkeep[1000110230] = 1;   # Na23
  tgtkeep[1000120240] = 1;   # Mg24
  tgtkeep[1000130270] = 1;   # Al27
  tgtkeep[1000140280] = 1;   # Si28
  tgtkeep[1000150310] = 1;   # P31
  tgtkeep[1000160320] = 1;   # S32
  tgtkeep[1000170350] = 1;   # Cl35
  tgtkeep[1000170360] = 1;   # Cl36
  tgtkeep[1000170370] = 1;   # Cl37
  tgtkeep[1000180400] = 1;   # Ar40
  tgtkeep[1000190390] = 1;   # K39
  tgtkeep[1000200400] = 1;   # Ca40
  tgtkeep[1000220480] = 1;   # Ti48
  tgtkeep[1000230510] = 1;   # V51
  tgtkeep[1000240520] = 1;   # Cr52
  tgtkeep[1000250550] = 1;   # Mn55
  tgtkeep[1000260540] = 1;   # Fe54
  tgtkeep[1000260560] = 1;   # Fe56
  tgtkeep[1000260570] = 1;   # Fe57
  tgtkeep[1000260580] = 1;   # Fe58
  tgtkeep[1000280580] = 1;   # Ni58
  tgtkeep[1000280590] = 1;   # Ni59
  tgtkeep[1000280600] = 1;   # Ni60
  tgtkeep[1000290630] = 1;   # Cu63
  tgtkeep[1000290640] = 1;   # Cu64
  tgtkeep[1000290650] = 1;   # Cu65
  tgtkeep[1000300640] = 1;   # Zn64
  tgtkeep[1000300650] = 1;   # Zn65
  tgtkeep[1000350800] = 1;   # Br80
  tgtkeep[1000360840] = 1;   # Kr84
  tgtkeep[1000410930] = 1;   # Nb93
  tgtkeep[1000420960] = 1;   # Mo96
  tgtkeep[1000441010] = 1;   # Ru101
  tgtkeep[1000501190] = 1;   # Sn119
  tgtkeep[1000541310] = 1;   # Xe131
  tgtkeep[1000561370] = 1;   # Ba137
  tgtkeep[1000641580] = 1;   # Gd158
  tgtkeep[1000741830] = 1;   # W183
  tgtkeep[1000741840] = 1;   # W184
  tgtkeep[1000791970] = 1;   # Au197
  tgtkeep[1000822070] = 1;   # Pb207
}
# decide whether to keep or reject a sub-process x-section based on the
# name string.  Note picking out "nu:XY" and "tgt:XYZ" is dependent on
# the exact naming formulation ... hopefully this won't change.
# example string:
#    <spline name="genie::AhrensNCELPXSec/Default/nu:-14;tgt:1000020040;N:2212;proc:Weak[NC],QES;" nknots="500">
#
/<spline/ {
  keep=0; doout=0;
  # check if we want this set, if yes set both keep & doout = 1
  split($0,array,";");
  split(array[2],tgtarray,":");
  tgtval=tgtarray[2];
  split(array[1],nuarray,"/");
  nuvaltmp=nuarray[3];
  split(nuvaltmp,nuarray,":");
  nuval=nuarray[2];
  #print "tgtarray[2] = ",tgtval," nuarray[2] = ",nuval;
  if ( tgtval in tgtkeep ) {
    #print "keep this tgt ",tgtval;
    if ( nuval in nukeep ) {
      keep=1; doout=1;
    } else {
      # print "reject this nu",nuval;
      keep=0; doout=0;
    }
  } else {
    #print "reject this tgt",tgtval;
    keep=0; doout=0;
  }
}
# close out a particular spline
/<\/spline/ {
  if ( doout == 1 ) { keep = 1 } else { keep = 0 }
  doout=1;
}
# regular lines depend on the current state
// {
  if ( keep  == 1 ) print $0;
  if ( doout == 1 ) keep = 1;
  nlines++;
  if ( maxlines > 0 && nlines > maxlines ) exit
}
# end-of-script reduce_gxspl.awk
