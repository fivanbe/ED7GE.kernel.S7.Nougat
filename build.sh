#!/bin/bash
#
# ED7GE kernel

# SETUP
# -----
export ARCH=arm64
export SUBARCH=arm64
export BUILD_CROSS_COMPILE=/home/fivanbe/ED7GE.kernel.S7.Nougat/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export CROSS_COMPILE=$BUILD_CROSS_COMPILE
export BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`


RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include
PAGE_SIZE=2048
DTB_PADDING=0

# PROGRAM START
# -------------
clear
echo "*************************"
echo "ED7GE Kernel Build Script"
echo "*************************"
echo ""
echo ""
echo "Crear Kernel para:"
echo ""
echo "(1)- S7 SM-G930F (flat)"
echo "(2)- S7 SM-G935F (edge)"
echo ""
read -p "Seleccione (1) S7 flat ó (2) S7 Edge? " prompt

if [ $prompt == "1" ]; then
    export MODEL=S7.flat
    KERNEL_DEFCONFIG=fivanbe-herolte_defconfig
    echo "S7 Flat G930F Seleccionado"
else [ $prompt == "2" ]
    export MODEL=S7.edge
    KERNEL_DEFCONFIG=fivanbe-hero2lte_defconfig
    echo "S7 Edge G935F Seleccionado"
fi

export K_VERSION="v1.9"
export KERNEL_VERSION="ED7GE.kernel.$MODEL.$K_VERSION"
export REVISION="RC"
export KBUILD_BUILD_VERSION="1"


# FUNCTIONS
# ---------
FUNC_DELETE_PLACEHOLDERS()
{
	find . -name \.placeholder -type f -delete
        echo "Placeholders de posición eliminados de Ramdisk"
        echo ""
}

FUNC_CLEAN_DTB()
{
	if ! [ -d $RDIR/arch/$ARCH/boot/dts ] ; then
		echo "Sin directorio : "$RDIR/arch/$ARCH/boot/dts""
	else
		echo "Eliminar archivos en : "$RDIR/arch/$ARCH/boot/dts/*.dtb""
		rm $RDIR/arch/$ARCH/boot/dts/*.dtb
		rm $RDIR/arch/$ARCH/boot/dtb/*.dtb
		rm $RDIR/arch/$ARCH/boot/boot.img-dtb
		rm $RDIR/arch/$ARCH/boot/boot.img-zImage
	fi
}

FUNC_BUILD_KERNEL()
{
	echo ""
        echo "Crear configuración común="$KERNEL_DEFCONFIG ""
        echo "Crear configuración variable="$MODEL ""
	FUNC_CLEAN_DTB
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			$KERNEL_DEFCONFIG || exit -1
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
	echo ""
}

FUNC_BUILD_DTB()
{
	[ -f "$DTCTOOL" ] || {
		echo "Necesitas ejecutar ./build.sh primero!"
		exit 1
	}
	case $MODEL in
	S7.flat)
		DTSFILES="exynos8890-herolte_eur_open_00 exynos8890-herolte_eur_open_01
				exynos8890-herolte_eur_open_02 exynos8890-herolte_eur_open_03
				exynos8890-herolte_eur_open_04 exynos8890-herolte_eur_open_08
				exynos8890-herolte_eur_open_09"
		;;
	S7.edge)
		DTSFILES="exynos8890-hero2lte_eur_open_00 exynos8890-hero2lte_eur_open_01
				exynos8890-hero2lte_eur_open_03 exynos8890-hero2lte_eur_open_04
				exynos8890-hero2lte_eur_open_08"
		;;
	*)
		echo "Dispositivo desconocido: $MODEL"
		exit 1
		;;
	esac
	mkdir -p $OUTDIR $DTBDIR
	cd $DTBDIR || {
		echo "No se puede copiar en $DTBDIR!"
		exit 1
	}
	rm -f ./*
	echo "Procesando archivos dts."
	for dts in $DTSFILES; do
		echo "=> Procesando: ${dts}.dts"
		${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
		echo "=> Generando: ${dts}.dtb"
		$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
	done
	echo "Generando dtb.img."
	$RDIR/scripts/dtbTool/dtbTool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE
	echo "Hecho."
}

FUNC_BUILD_RAMDISK()
{
	echo ""
	echo "Construyendo Ramdisk"
	mv $RDIR/arch/$ARCH/boot/Image $RDIR/arch/$ARCH/boot/boot.img-zImage
	mv $RDIR/arch/$ARCH/boot/dtb.img $RDIR/arch/$ARCH/boot/boot.img-dtb
	
	cd $RDIR/build
	mkdir temp
	cp -rf aik/. temp
	cp -rf ramdisk/. temp
	
	rm -f temp/split_img/boot.img-zImage
	rm -f temp/split_img/boot.img-dtb
	mv $RDIR/arch/$ARCH/boot/boot.img-zImage temp/split_img/boot.img-zImage
	mv $RDIR/arch/$ARCH/boot/boot.img-dtb temp/split_img/boot.img-dtb
	cd temp

	case $MODEL in
	S7.edge)
		echo "Ramdisk para G935"
		;;
	S7.flat)
		echo "Ramdisk para G930"
		sed -i 's/G935/G930/g' ramdisk/default.prop
		sed -i 's/hero2/hero/g' ramdisk/default.prop
		sed -i 's/hero2/hero/g' ramdisk/property_contexts
		sed -i 's/hero2/hero/g' ramdisk/service_contexts
		sed -i '/sys\/class\/lcd\/panel\/mcd_mode/d' ramdisk/init.samsungexynos8890.rc
		sed -i 's/SRPOI30A000KU/SRPOI17A000KU/g' split_img/boot.img-board
		;;
	esac
		echo "Hecho"

	./repackimg.sh

	cp -f image-new.img $RDIR/build
	cd ..
	rm -rf temp
	echo SEANDROIDENFORCE >> image-new.img
}

FUNC_BUILD_FLASHABLES()
{
	cd $RDIR/build
	mkdir temp2

    	mv image-new.img temp2/boot.img
    	cp -rf zip/common/. temp2
    	#cp -rf zip/$MODEL/. temp2
	cd temp2
	zip -9 -r ../$KERNEL_VERSION.zip *
	cd ..
    	rm -rf temp2
}

# MAIN PROGRAM
# ------------

sh ./clean.sh

(
	START_TIME=`date +%s`
	FUNC_DELETE_PLACEHOLDERS
	FUNC_BUILD_KERNEL
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	FUNC_BUILD_FLASHABLES
	END_TIME=`date +%s`
	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo ""
	echo "Tienpo total del compilado $ELAPSED_TIME segundos"
	echo ""
) 2>&1 | tee -a ./build.log

	echo "El flasheable se encuentra en la carpeta build"
	echo ""


