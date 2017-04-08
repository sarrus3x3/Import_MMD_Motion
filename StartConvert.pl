# 2017/02/19
# 2017/03/10 23:58 とりあえずコーディング完了。今からデバッグ。
# 2017/03/12 14:45
# 次のバグを確認：
# * 全ての親ボーン／ガイド自体の変換ができていない。
# * 足IKの位置の変換がうまくいっていない...
# → 対処を。
# 19:11
# いい加減amazonでの注文をしなくては...
# vmdデータの読込／書出と、
# vmdデータの編集（変換）処理
# は全く別の処理なので、できればファイルをわけるようにしたい。
# → これは仕様バグというか、MMDの仕組みをよくわかっていなかったのかもしれないぞ？
#    IKのボーン情報に関する理解不足。
#    IKどものBonePosは親ボーンの座標系で設定されているわけではないのか？？？
#    それによるアルゴリズムレベルの基幹設計に誤りがあった。
# 23:41 
# 該当問題がIKボーンに限って発生するわけではないことを確認。
# 該当問題について設計の修正方法を確認
# 2017/03/13 20:25
# 上記修正方法を実装完了。
# 一応、簡単に確認もした。


# ＊＊＊ ツールの目的 ＊＊＊
# VMDファイルの編集（暫定）

# ＊＊＊ ツールの使い方 ＊＊＊
# ツールの配置されているディレクトリでコマンドプロンプトを開き、
#   >perl BinaryExpress.pl [vmdファイル名].vmd
# ツールと同ディレクトリに、csvに変換した
#   [vmdファイル名]_Convert.csv
# ファイルが生成される。
# ★ とりあえず、csv出力は標準出力にしておく。

# ＊＊＊ 出力形式 ＊＊＊
# 各ボーン毎に、横軸がブレーム番号と縦軸が属性（ボーン位置など）の表を出力する。
# 出力する属性は以下：
# * ボーンのX軸位置
# * ボーンのY軸位置
# * ボーンのZ軸位置
# * ボーンのクォータニオンのX
# * ボーンのクォータニオンのY
# * ボーンのクォータニオンのZ
# * ボーンのクォータニオンのW
# 補間パラメータの出力は省略

# ＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊
# ＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊
# ＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊

# ◆ vmdデータの構造
# 特にフレームデータのフォーマット情報。
# （vmdデータにはそれ以外にもカメラデータなども持っているらしいが、今回必要なのはフレームデータのみ）
# http://atupdate.web.fc2.com/vmd_format.htm

# vmdデータの日本語文字列で使われる文字コード
# 文字コードはシフトJIS
# 終端 0x00, パディング 0xFD(PMXモデルで保存した場合はパディング 0x00)
# http://harigane.at.webry.info/201103/article_1.html

# ◆ perlでのバイナリデータを扱う
# http://www.tohoho-web.com/perl/binary.htm

# ソースの元ネタ
# https://hgotoh.jp/wiki/doku.php/documents/perl/perl-0002

# フレームデータは、フレーム順に並んでいるわけではないらしいので、
# 一度、vmdデータを全て読み込んで、合成位置を計算し、
# それを書き込むために再度読み込み直す、という処理が必要になる。

# センター位置を直しただけでは上手くいかない。
# 足のIKの位置も併せて修正する必要があるよう？
# → 上手くいった、よっしゃああああ！

# ＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊＊

# 2017/01/29
# ・先頭と最後に変なデータが入る。（framenumがめちゃくちゃなことから、違うフォーマットであることは確か）
#   → フレームデータ以外のものだろうか... もっと詳しいフォーマット情報がないと...
#   → sortしているから、後ろの方で出力された変なデータが出力されているだけだ。気にしなくていい。
# ・IKにもクオータニオンが入る。これは困ったなぁ...
#   → この謎を解明しなくては...


# 宣言無しでの変数の使用不可
use strict;

#日本語対応。
use utf8;
use Encode qw/encode decode/;

# 行列演算のためのモジュール
use Math::MatrixReal;

# 別ファイルのサブルーチンを呼び出す
require "ArithmeticSubroutines.pl";

# ------------------------ ここから ---------------------------
my $code;

###### 変数定義

# 接頭句（char[30]）"Vocaloid Motion Data 0002\0" の文字列
my $Prefix;

# モデル名（char[20]）
my $ModelName;

# フレームデータ数
my $MaxFrameNum;

# vmdデータの格納用ハッシュ
my %VmdDataHash;

# フレーム番号を格納するハッシュ
my %FrameNumHash;

# 変換ボーンについての情報ファイル
my $CnvBoneDataFile = "ConvertBoneData.txt";

###### 読み込みvmdデータの準備

my $VmdDataFile = decode('cp932', $ARGV[0] );
#my $VmdDataFile = "sampledata.vmd";

# vmdデータをopen
open ( IN, encode('cp932', $VmdDataFile ) ) or die "$!";
binmode(IN); # バイナリモードにセット

###### vmd ファイルの読み込み開始

###### ヘッダー部の解析

# 接頭句の抽出
last if undef == read(IN, $code, 30); 
$Prefix = unpack("Z*",$code);  # ヌル文字で終わる文字列。配列の最後まで処理するには最後に"*"をつけなきゃいけない。使い方についてのドキュメントが殆ど無い...

# モデル名の抽出
last if undef == read(IN, $code, 20); 
$ModelName = unpack("Z*",$code);  # ヌル文字で終わる文字列。配列の最後まで処理するには最後に"*"をつけなきゃいけない。使い方についてのドキュメントが殆ど無い...

# フレームデータ数の抽出
last if undef == read(IN, $code, 4 );
$MaxFrameNum = unpack("L",$code); # unsigned log

print "Prefix:"     , $Prefix,      "\n";
print "ModelName:"  , $ModelName,   "\n";
print "MaxFrameNum:", $MaxFrameNum, "\n";

###### フレームデータの解析開始

foreach my $f ( 0 .. $MaxFrameNum-1 )
{
	my @binarray; # 読みだしたバイナリを格納
	
	my $bonename; # "頭\0"などのボーン名の文字列
	my $framenum; # フレーム番号
	
	my $boneposX; # ボーンのX軸位置。位置データがない場合は0
	my $boneposY; # ボーンのY軸位置。位置データがない場合は0
	my $boneposZ; # ボーンのZ軸位置。位置データがない場合は0
	
	my $QuatnioX; # ボーンのクォータニオンのX。データがない場合は0
	my $QuatnioY; # ボーンのクォータニオンのY。データがない場合は0
	my $QuatnioZ; # ボーンのクォータニオンのZ。データがない場合は0
	my $QuatnioW; # ボーンのクォータニオンのW。データがない場合は0
	
	# ボーン名 ～ ボーン位置情報までを読出し
	last if undef == read(IN, $binarray[0], 15); # ボーン名
	last if undef == read(IN, $binarray[1], 4);  # フレーム番号
	last if undef == read(IN, $binarray[2], 4);  # ボーンのX軸位置
	last if undef == read(IN, $binarray[3], 4);  # ボーンのY軸位置
	last if undef == read(IN, $binarray[4], 4);  # ボーンのZ軸位置
	last if undef == read(IN, $binarray[5], 4);  # ボーンのクォータニオンのX
	last if undef == read(IN, $binarray[6], 4);  # ボーンのクォータニオンのY
	last if undef == read(IN, $binarray[7], 4);  # ボーンのクォータニオンのZ
	last if undef == read(IN, $binarray[8], 4);  # ボーンのクォータニオンのW
	last if undef == read(IN, $binarray[9], 64 ); # 補間パラメータ（使用しない）

	$bonename = unpack("Z*",$binarray[0]);  # ヌル文字で終わる文字列。配列の最後まで処理するには最後に"*"をつけなきゃいけない。使い方についてのドキュメントが殆ど無い...
	$framenum = unpack("L" ,$binarray[1]);  # unsigned log
	$boneposX = unpack("f" ,$binarray[2]);
	$boneposY = unpack("f" ,$binarray[3]);
	$boneposZ = unpack("f" ,$binarray[4]);
	$QuatnioX = unpack("f" ,$binarray[5]);
	$QuatnioY = unpack("f" ,$binarray[6]);
	$QuatnioZ = unpack("f" ,$binarray[7]);
	$QuatnioW = unpack("f" ,$binarray[8]);
	
	# フレーム番号を記録
	$FrameNumHash{$framenum} += 1;
	
	# 念のため、ボーン名を内部文字列に変換しておく
	$bonename = decode('SJIS', $bonename );
	
	# フレームデータをハッシュに格納
	$VmdDataHash{$bonename}{$framenum} = { 
		'boneposX' => $boneposX,
		'boneposY' => $boneposY,
		'boneposZ' => $boneposZ,
		'QuatnioX' => $QuatnioX,
		'QuatnioY' => $QuatnioY,
		'QuatnioZ' => $QuatnioZ,
		'QuatnioW' => $QuatnioW
		};
	
	
}

# csv出力（タブ区切り）
foreach my $bonename ( sort keys %VmdDataHash ){
	# ボーン名を出力
	print encode('cp932', $bonename );
	print encode('cp932', "\n" );
	
	# 各属性のラインを定義
	my $line_framenum ="framenum:";
	my $line_boneposX ="boneposX:";
	my $line_boneposY ="boneposY:";
	my $line_boneposZ ="boneposZ:";
	my $line_QuatnioX ="QuatnioX:";
	my $line_QuatnioY ="QuatnioY:";;
	my $line_QuatnioZ ="QuatnioZ:";;
	my $line_QuatnioW ="QuatnioW:";;
	
	foreach my $framenum ( sort {$a <=> $b} keys %{$VmdDataHash{$bonename}} ){ # 数値昇順ソートする
		$line_framenum .= "\t". $framenum;
		$line_boneposX .= "\t". $VmdDataHash{$bonename}{$framenum}{'boneposX'};
		$line_boneposY .= "\t". $VmdDataHash{$bonename}{$framenum}{'boneposY'};
		$line_boneposZ .= "\t". $VmdDataHash{$bonename}{$framenum}{'boneposZ'};
		$line_QuatnioX .= "\t". $VmdDataHash{$bonename}{$framenum}{'QuatnioX'};
		$line_QuatnioY .= "\t". $VmdDataHash{$bonename}{$framenum}{'QuatnioY'};
		$line_QuatnioZ .= "\t". $VmdDataHash{$bonename}{$framenum}{'QuatnioZ'};
		$line_QuatnioW .= "\t". $VmdDataHash{$bonename}{$framenum}{'QuatnioW'};
		
	}
	
	# 最後に改行を付与
	$line_framenum .= "\n";
	$line_boneposX .= "\n";
	$line_boneposY .= "\n";
	$line_boneposZ .= "\n";
	$line_QuatnioX .= "\n";
	$line_QuatnioY .= "\n";
	$line_QuatnioZ .= "\n";
	$line_QuatnioW .= "\n";
	
	# 各属性のラインを出力
	print encode('cp932', $line_framenum );
	print encode('cp932', $line_boneposX );
	print encode('cp932', $line_boneposY );
	print encode('cp932', $line_boneposZ );
	print encode('cp932', $line_QuatnioX );
	print encode('cp932', $line_QuatnioY );
	print encode('cp932', $line_QuatnioZ );
	print encode('cp932', $line_QuatnioW );
	
	# ボーンの区切り
	print encode('cp932', "--------------\n" );
	
}

###### VmdDataHash を編集する（お好きなように）

# 現行の「全ての親」ボーンの名前
my $OldParentBoneName="全ての親";

# 変換後「全ての親」ボーンの名前
my $NewParentBoneName="ガイド";

# 変換対象ボーン(=「全ての親」ボーンの子ボーン)のリスト
my @CnvTargetBoneList; 

# 変換対象ボーンのボーン座標から計算した平行移動行列
my %SftMatsForBones;

# 変換対象ボーンのボーン座標から計算した平行移動行列の逆行列
# → その都度計算すればいいかぁ。

# CnvTargetBoneList を外部ファイルから読込
open ( _IN, $CnvBoneDataFile ) or die "$!";
while (<_IN>) {
	my $line = $_;
	chomp ($line); # 改行コードの除去
	$line = decode('SJIS', $line );
	
	# ボーン名の後に、カンマ区切りでボーン座標を格納
	my @data = split( /,/ , $line ); # 各行をカンマ区切りで分割
	
	# CnvTargetBoneList にボーン名を格納
	push @CnvTargetBoneList, $data[0];
	
	# この時に同時にボーン座標から平行移動行列を計算し、ハッシュに格納
	$SftMatsForBones{$data[0]} = &MGetTranslate( $data[1], $data[2], $data[3] );
	
}
close(_IN);

# 変換ターゲットボーンを表示
print "Convert Target Bone is:\n";
print encode('cp932', join(',',@CnvTargetBoneList)), "\n";
print "-----\n";


# フレーム毎に実施
foreach my $frame (keys %FrameNumHash)
{
	# 前処理：該当フレームが、変換処理実施可能かのチェックをする。
	# （必要なボーンにキーが打ってあるかをチェックする。）
	
	# 制御フラグ
	my $ConvFlg;

	# if 該当フレームに現「全ての親」ボーンと新「全ての親」ボーンの両方が登録されている？
	if( exists($VmdDataHash{$OldParentBoneName}{$frame}) && exists($VmdDataHash{$NewParentBoneName}{$frame}))
	{
		# YES → ConvFlg:ON
		$ConvFlg = "ON";
	}
	# elsif 該当フレームに現「全ての親」ボーンと新「全ての親」ボーンの両方とも登録されていない？
	elsif( !exists($VmdDataHash{$OldParentBoneName}{$frame}) && !exists($VmdDataHash{$NewParentBoneName}{$frame}))
	{
		# YES → ConvFlg:OFF
		$ConvFlg = "OFF";
	}
	# else
	else
	{
		# → 異常終了ルート
		die("Error 01");
	}

	### 変換対象ボーンのボーン情報変換処理開始
	#   【注意】
	#   全ての親ボーンのキーが打ってあるフレームでも、
	#   子ボーンのキーが打っていなければ、その小ボーンの位置／姿勢には
	#   変換が適用されない（当たり前だが）ので、モーション設計時は注意すること。

	## 対象ボーンの位置座標の変換行列を計算
	
	my $MSft;   # 平行移動行列
	my $MRot;   # 回転行列

	# 現「全ての親」ボーンの座標変換行列を計算
	my @Bonepos = &GetVec3FromHash($VmdDataHash{$OldParentBoneName}{$frame});
	$MSft = &MGetTranslate(@Bonepos);
	
	my @QuatnioOld = &GetQuatnioFromHash($VmdDataHash{$OldParentBoneName}{$frame});
	$MRot = &MGetRotQuaternion(@QuatnioOld);
	
	my $MTransOld = $MSft * $MRot;

	# 新「全ての親」ボーンの座標変換行列を計算
	my @Bonepos = &GetVec3FromHash($VmdDataHash{$NewParentBoneName}{$frame});
	$MSft = &MGetTranslate(@Bonepos);
	
	my @QuatnioNew = &GetQuatnioFromHash($VmdDataHash{$NewParentBoneName}{$frame}) ;
	$MRot = &MGetRotQuaternion(@QuatnioNew);
	
	my $MTransNew = $MSft * $MRot;

	# 位置座標の変換行列を計算
	my $MTransBonePos = $MTransNew->inverse * $MTransOld;
	
	## 対象ボーンのクォータニオンの変換クォータニオンを計算
	
	# QuatnioNew のインバース計算
	my @QuatnioNewInv = &GetInversQuaternion(@QuatnioNew);
	
	# QuatnioNew->invsers * QuatnioOld
	my @qTransQuatnio = &QuatMult( @QuatnioNewInv, @QuatnioOld );
	
	## 現「全ての親」ボーンのボーン情報を新「全ての親」ボーンのボーン情報に書き換える。
	
	&CopyHashBoneInfo( $VmdDataHash{$NewParentBoneName}{$frame} , $VmdDataHash{$OldParentBoneName}{$frame} );

	## for:全ての対象ボーンについて
	foreach my $TargetBoneName ( @CnvTargetBoneList )
	{
		if( exists $VmdDataHash{$TargetBoneName}{$frame} )
		{
			# if ConvFlg:OFF 
			#    → 異常終了ルート
			if( $ConvFlg eq "OFF" )
			{
				die("Error 02");
			}

			## ボーンの位置座標の変換
			
			# $VmdDataHash{$TargetBoneName}{$frame} から CurBonePos を取得
			my @CurBonePos = &GetVec3FromHash($VmdDataHash{$TargetBoneName}{$frame});
			
			# CurBonePos を行列形式に変換
			my $MCurBonePos = &CnvArrayToMatrix(@CurBonePos);
			
			# 行列 $MTransBonePos を作用させて変換 → CnvBonePos
			# ボーン座標についても考慮する。
			my $MCnvBonePos = $SftMatsForBones{$TargetBoneName}->inverse
								 * $MTransBonePos
								 * $SftMatsForBones{$TargetBoneName}
								 * $MCurBonePos;
			
			# CnvBonePos を配列形式に変換
			my @CnvBonePos = &CnvMatrixToArray( $MCnvBonePos );
			
			# $VmdDataHash に書き戻す。
			&SetVec3ToHash($VmdDataHash{$TargetBoneName}{$frame}, @CnvBonePos );
			
			## ボーンのクォータニオンの変換

			# $VmdDataHash{$TargetBoneName}{$frame} から CurQuatnio を取得
			my @CurQuatnio = &GetQuatnioFromHash($VmdDataHash{$TargetBoneName}{$frame});
			
			# 行列 $qTransQuatnio を作用させて変換 → CnvQuatnio
			my @CnvQuatnio = &QuatMult( @qTransQuatnio, @CurQuatnio );
			
			# $VmdDataHash に書き戻す。
			&SetQuatnioToHash( $VmdDataHash{$TargetBoneName}{$frame}, @CnvQuatnio );
			
		}
	
	}

}

###### 出力vmdデータの準備

# 書き戻しのために、入力vmdデータファイルを開き直す
open ( IN, encode('cp932', $VmdDataFile ) ) or die "$!";
binmode(IN); # バイナリモードにセット

# 書き戻し用のファイルを開く
my $EditedVmdDataFile = "[Convert]_" . $VmdDataFile ;
open ( OUT, encode('cp932', ">$EditedVmdDataFile" ) ) or die "$!"; 
binmode(OUT); # バイナリモードにセット


###### vmdデータの書き戻し開始

# フレームデータの場所までシフト
read( IN, $code, 54 ); 
print OUT $code ;

# フレームデータの読み込み
foreach my $f ( 0 .. $MaxFrameNum-1 )
{
	my @binarray; # 読みだしたバイナリを格納
	
	my $bonename; # "頭\0"などのボーン名の文字列
	my $framenum; # フレーム番号
	
	my $boneposX; # ボーンのX軸位置。位置データがない場合は0
	my $boneposY; # ボーンのY軸位置。位置データがない場合は0
	my $boneposZ; # ボーンのZ軸位置。位置データがない場合は0
	
	my $QuatnioX; # ボーンのクォータニオンのX。データがない場合は0
	my $QuatnioY; # ボーンのクォータニオンのY。データがない場合は0
	my $QuatnioZ; # ボーンのクォータニオンのZ。データがない場合は0
	my $QuatnioW; # ボーンのクォータニオンのW。データがない場合は0
	
	# ボーン名 ～ ボーン位置情報までを読出し
	last if undef == read(IN, $binarray[0], 15); # ボーン名
	last if undef == read(IN, $binarray[1], 4);  # フレーム番号
	last if undef == read(IN, $binarray[2], 4);  # ボーンのX軸位置
	last if undef == read(IN, $binarray[3], 4);  # ボーンのY軸位置
	last if undef == read(IN, $binarray[4], 4);  # ボーンのZ軸位置
	last if undef == read(IN, $binarray[5], 4);  # ボーンのクォータニオンのX
	last if undef == read(IN, $binarray[6], 4);  # ボーンのクォータニオンのY
	last if undef == read(IN, $binarray[7], 4);  # ボーンのクォータニオンのZ
	last if undef == read(IN, $binarray[8], 4);  # ボーンのクォータニオンのW
	last if undef == read(IN, $binarray[9], 64 ); # 補間パラメータ（使用しない）

	$bonename = unpack("Z*",$binarray[0]);  # ヌル文字で終わる文字列。配列の最後まで処理するには最後に"*"をつけなきゃいけない。使い方についてのドキュメントが殆ど無い...
	$framenum = unpack("L" ,$binarray[1]);  # unsigned log
	
	# 念のため、ボーン名を内部文字列に変換しておく
	$bonename = decode('SJIS', $bonename );
	
	# $VmdDataHash{$bonename}{$framenum} のデータを書き戻す
	$binarray[2] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'boneposX'} );
	$binarray[3] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'boneposY'} );
	$binarray[4] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'boneposZ'} );
	$binarray[5] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'QuatnioX'} );
	$binarray[6] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'QuatnioY'} );
	$binarray[7] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'QuatnioZ'} );
	$binarray[8] = pack("f" , $VmdDataHash{$bonename}{$framenum}{'QuatnioW'} );
	
	# バイナリデータを書き戻し ...
	foreach my $i ( 0 .. 9 )
	{
		print OUT $binarray[$i] ;
	}
	
}

# 残りのバイナリデータを読みだして、書き戻す。
while( read(IN, $code, 1) )
{
	print OUT $code ;
}

print "\n";
print "Convert Complete. File: ", encode('cp932', $EditedVmdDataFile ), " is created.\n";
print "--- end\n";

#################### サブルーチンを定義 ####################

# 逆クォータニオンを計算
sub GetInversQuaternion
{
	my ( $x, $y, $z, $w ) = @_;
	
	return ( -$x, -$y, -$z, $w );

}

# ベクトルを配列形式→行列形式に変換
sub CnvArrayToMatrix
{
	my ( $x, $y, $z ) = @_;
	my @array_work = ( [$x], [$y], [$z], [1] );
	my $VecMat = Math::MatrixReal->new_from_rows(\@array_work);
	
	return $VecMat;
	
}

# ベクトルを行列形式→配列形式に変換
sub CnvMatrixToArray
{
	my ( $VecMat ) = @_;
	
	return ( $VecMat->element(1,1), $VecMat->element(2,1), $VecMat->element(3,1) );
}

# ハッシュから3次元ベクトルを抽出
sub GetVec3FromHash
{
	my ( $hash ) = @_;
	my @Vector;
	
	$Vector[0] = $$hash{'boneposX'};
	$Vector[1] = $$hash{'boneposY'};
	$Vector[2] = $$hash{'boneposZ'};
	
	return @Vector;
}

# ハッシュからクォータニオンを抽出
sub GetQuatnioFromHash
{
	my ( $hash ) = @_;
	my @Quatnio;
	
	$Quatnio[0] = $$hash{'QuatnioX'};
	$Quatnio[1] = $$hash{'QuatnioY'};
	$Quatnio[2] = $$hash{'QuatnioZ'};
	$Quatnio[3] = $$hash{'QuatnioW'};
	
	return @Quatnio;
}

# 3次元ベクトルをハッシュに代入
sub SetVec3ToHash
{
	my ( $hash, @Vector) = @_;
	
	$$hash{'boneposX'} = $Vector[0];
	$$hash{'boneposY'} = $Vector[1];
	$$hash{'boneposZ'} = $Vector[2];
	
}

# クォータニオンをハッシュに代入
sub SetQuatnioToHash
{
	my ( $hash, @Quatnio) = @_;
	
	$$hash{'QuatnioX'} = $Quatnio[0];
	$$hash{'QuatnioY'} = $Quatnio[1];
	$$hash{'QuatnioZ'} = $Quatnio[2];
	$$hash{'QuatnioW'} = $Quatnio[3];

}

# ボーン情報（位置・姿勢）をハッシュから別のハッシュにコピーする。
sub CopyHashBoneInfo
{
	my ( $frm_hash, $to_hash ) = @_;

	$$to_hash{'boneposX'} = $$frm_hash{'boneposX'};
	$$to_hash{'boneposY'} = $$frm_hash{'boneposY'};
	$$to_hash{'boneposZ'} = $$frm_hash{'boneposZ'};
	$$to_hash{'QuatnioX'} = $$frm_hash{'QuatnioX'};
	$$to_hash{'QuatnioY'} = $$frm_hash{'QuatnioY'};
	$$to_hash{'QuatnioZ'} = $$frm_hash{'QuatnioZ'};
	$$to_hash{'QuatnioW'} = $$frm_hash{'QuatnioW'};

}


