//INPUT/OUPUT
#@ String (label=" ", value="<html><font size=5><font color=purple><b>Oligodendrocyte Differentiation</b></font><br><font color=black>Pre-processing</font></html>", visibility=MESSAGE, persist=false) heading
#@ File(label="Select an input directory:", style="directory") inDir
#@ String (label=" ", value="<html><img src=\"http://www.crm.ed.ac.uk/sites/default/themes/website/logo.png\"></html>", visibility=MESSAGE, persist=false) logo1
myList=getFileList(inDir);
outDir=inDir+File.separator+"_out";
File.makeDirectory(outDir);

//CLEAR LOG
print("\\Clear");
// CLOSE ALL OPEN IMAGES
while (nImages>0) { 
	selectImage(nImages); 
    close(); 
}
//SET BATCH MODE 
setBatchMode(true);
setOption("ExpandableArrays", true);

//FILE MANAGEMENT
batchFiles=0;
for (i=0; i<myList.length; i++) {
	if (endsWith(myList[i], "/") && indexOf(myList[i], "_B") != -1) {
		batchFiles++;
	}
}

//check that the directory contains BATCH files
if (batchFiles==0) {
	beep();
	exit("No batch files")
}

//create an array containing only the names of the SLICE folders in the directory path
batchArray=newArray(batchFiles);
batchCode=newArray(batchFiles);
count=0;
for (i=0; i<myList.length; i++) {
	if (endsWith(myList[i], "/") && indexOf(myList[i], "_B") != -1) {
		batchArray[count]=myList[i];
		batchCode[count]=substring(myList[i], indexOf(myList[i], "_B") + 1, lengthOf(myList[i]) - 1);
		count++;
	}
}
Array.sort(batchArray);


for (i=0; i<batchArray.length; i++) {
	batchList=getFileList(inDir+File.separator+batchArray[i]);
	nd2Files=0;
	for (j=0; j<batchList.length; j++) {
		if (endsWith(batchList[j], ".nd2")) {
			nd2Files++;
		}
	}
	
	if (nd2Files>0) {	
		//create an array containing only the names of the ND2 files in the directory path
		nd2Array=newArray(nd2Files);
		count=0;
		for (j=0; j<batchList.length; j++) {
			if (endsWith(batchList[j], ".nd2")) {
				nd2Array[count]=batchList[j];
				count++;
			}
		}
		Array.sort(nd2Array);
	
		for (j=0; j<nd2Array.length; j++) {
			indexOfDot=indexOf(nd2Array[j], ".nd2");
			truncatedFileName=substring(nd2Array[j], 0, indexOfDot-3);
			// concatenate folder name with files name
			newFileName=substring(batchArray[i], 0, lengthOf(batchArray[i]) - 1)+"_"+truncatedFileName;
			print("Renaming: " + newFileName);
			run("Bio-Formats", "open=["+inDir+File.separator+batchArray[i]+File.separator+nd2Array[j]+"] color_mode=Grayscale rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
			//open(inDir+File.separator+batchArray[i]+File.separator+nd2Array[j]);
			Stack.getDimensions(width, height, channels, slices, frames);
			for (k=1; k<=slices; k++) {
				for (l=1; l<=channels; l++) {
					run("Duplicate...", "duplicate channels="+l+" slices="+k);
					run("Grays");
					saveAs("tif", outDir+File.separator+newFileName+"_C"+l+"_Z"+k+".nd2");
					close();
				}
			}
			run("Close All");
			//File.rename(inDir+File.separator+batchArray[i]+File.separator+nd2Array[j], inDir+File.separator+batchArray[i]+File.separator+newFileName);
		}
	}
}
setBatchMode(false);