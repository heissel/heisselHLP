#!/usr/bin/perl

$what = shift;

if ($what eq 'ex4') {
    # copy the ex4 files ffrom the test account, then distribute them to the various installations
    foreach $file (</Users/tdall/geniustrader/MT4_dev/experts/*.mq4>) {
        $file =~ /experts\/(.*).mq4/;
        `cp /Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_xtb_/drive_c/Program\\ Files/MetaTrader\\ FLOAT/experts/$1.ex4 /Users/tdall/geniustrader/MT4_dev/experts_compiled/.`;
    }
    foreach $file (</Users/tdall/geniustrader/MT4_dev/experts/indicators/*.mq4>) {
        $file =~ /indicators\/(.*).mq4/;
        `cp /Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_xtb_/drive_c/Program\\ Files/MetaTrader\\ FLOAT/experts/indicators/$1.ex4 /Users/tdall/geniustrader/MT4_dev/experts_compiled/indicators/.`;
    }
} 
if ($what) {
    @targets = ();
    push @targets, '/Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_xtb_/drive_c/Program\ Files/MetaTrader\ FLOAT/experts' unless ($what eq 'ex4'); # the testing dir
    if ($what eq 'all' || $what eq 'ex4') {
        push @targets, '/Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_/drive_c/Program\ Files/MetaTrader\ 4/experts';
        push @targets, '/Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_Admiral_/drive_c/Program\ Files/MetaTrader\ 4\ Admiral\ Markets\ AS/experts';
        push @targets, '/Applications/AdmiralMarketsMT4.app/Contents/Resources/drive_c/Program\ Files/MetaTrader\ 4\ Admiral\ Markets\ AS/experts';
        push @targets, '/Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_GFT_DEMO_/drive_c/Program\ Files/GFT_MT4\ Powered\ by\ BT/experts';
        push @targets, '/Users/tdall/Library/PlayOnMac/wineprefix/MetaTrader_4_JFD_/drive_c/Program\ Files/JFD\ Brokers\ MetaTrader\ 4/experts';
    }
    foreach $target (@targets) { 
        `rsync -a /Users/tdall/geniustrader/MT4_dev/experts/ $target`;
        if ($what eq 'ex4') {
            `cp /Users/tdall/geniustrader/MT4_dev/experts_compiled/*.ex4 $target/.`;
            `cp /Users/tdall/geniustrader/MT4_dev/experts_compiled/indicators/*.ex4 $target/indicators/.`;
        }
    }
}