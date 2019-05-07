//INPUT/OUPUT
#@ String (label=" ", value="<html><font size=5><font color=purple><b>Oligodendrocyte Differentiation</b></font><br><font color=black>Pre-processing</font></html>", visibility=MESSAGE, persist=false) heading
#@ String(label="Select mode:", choices={"Rename", "Rename + Create flat-field", "Projections", "Projections + Flat-field correction"}, style="radioButtonVertical") mode
#@ File(label="Select an input directory:", style="directory") inDir
#@ String (label=" ", value="<html><img src=\"http://www.crm.ed.ac.uk/sites/default/themes/website/logo.png\"></html>", visibility=MESSAGE, persist=false) logo1
myList=getFileList(inDir);  //an array

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

//RENAME + CREATE FLAT-FIELD
if (mode=="Rename" || mode=="Rename + Create flat-field") {
	//RENAME
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
				newFileName=substring(batchArray[i], 0, lengthOf(batchArray[i]) - 1)+"_"+truncatedFileName+".nd2";
				print("Renaming: " + newFileName);
				File.rename(inDir+File.separator+batchArray[i]+File.separator+nd2Array[j], inDir+File.separator+batchArray[i]+File.separator+newFileName);

				
				//CREATE FLAT-FIELD
				if (mode=="Rename + Create flat-field") {
					run("Bio-Formats", "open=["+inDir+File.separator+batchArray[i]+File.separator+newFileName+"] color_mode=Grayscale rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
					Stack.getDimensions(width, height, channels, slices, frames);
					for (k=0; k<channels; k++) {
						Stack.setChannel(k);
						run("Duplicate...", "title=C"+k+1+"_"+newFileName);
						run("Grays");
						selectImage(newFileName);
					}
				}
				close(newFileName);
			}

			if (mode=="Rename + Create flat-field") {
				for (j=0; j<channels; j++) {
					run("Images to Stack", "name=C"+j+1+"_stack title=C"+j+1+" use");
					run("BaSiC ", "processing_stack=C"+j+1+"_stack flat-field=None dark-field=None shading_estimation=[Estimate shading profiles] shading_model=[Estimate flat-field only (ignore dark-field)] setting_regularisationparametes=Automatic temporal_drift=Ignore correction_options=[Compute shading only] lambda_flat=0.50 lambda_dark=0.50");
					flatFieldID="Flat-field_C"+j+1+"_"+substring(batchArray[i], 0, lengthOf(batchArray[i]) - 1);
					rename(flatFieldID);
					saveAs("tif", inDir+File.separator+batchArray[i]+File.separator+flatFieldID);
					close("C"+j+1+"_stack");
					close(flatFieldID);
				}
				run("Close All");
			}
		}
	}
}

//PREPROCESS
if (mode=="Projections" || mode=="Projections + Flat-field correction") {

	//'Slide Selection' dialog box
	selectionOptions=newArray("Select All", "Include", "Exclude");
	fileCheckbox=newArray(batchArray.length);
	selection=newArray(batchArray.length);
	title = "Select slides";
	Dialog.create(title);
	Dialog.addRadioButtonGroup("", selectionOptions, 3, 1, selectionOptions[0]);
	Dialog.addCheckboxGroup(sqrt(batchArray.length) + 1, sqrt(batchArray.length) + 1, batchCode, selection);
	Dialog.show();
	selectionMode=Dialog.getRadioButton();
	for (i=0; i<batchArray.length; i++) {
		fileCheckbox[i]=Dialog.getCheckbox();
		if (selectionMode=="Select All") {
			fileCheckbox[i]=true;
		} else if (selectionMode=="Exclude") {
			if (fileCheckbox[i]==true) {
				fileCheckbox[i]=false;
			} else {
				fileCheckbox[i]=true;
			}
		}
	}
	
	//check that at least one BATCH folder have been selected
	checkSelection = 0;
	for (i=0; i<batchArray.length; i++) {
		checkSelection += fileCheckbox[i];
	}
	
	if (checkSelection == 0) {
		exit("There is no batch folder selected");
	}

	//name the output directory
	var maxOut;
	outDirString=File.getName(inDir)+"_OUT";
	parentList=getFileList(File.getParent(inDir));
	outFoldersCount=0;
	for (i=0; i<parentList.length; i++) {
		if (indexOf(parentList[i], outDirString)!=-1) {
			outFoldersCount++;
		}
	}
	if (outFoldersCount == 0) {
		outDir=File.getParent(inDir)+"\\"+File.getName(inDir)+"_OUT"+1;
	} else {
		outFoldersCount2=0;
		outFolders=newArray(outFoldersCount);
		for (i=0; i<parentList.length; i++) {
			if (indexOf(parentList[i], outDirString)!=-1) {
				outFolders[outFoldersCount2]=parentList[i];
				outFoldersCount2++;
			}
		}
		outNumber=newArray(outFolders.length);
		for (i=0; i<outFolders.length; i++) {
			outNumberString=substring(outFolders[i], indexOf(outFolders[i], "OUT") + 3, lengthOf(outFolders[i]) - 1);
			outNumber[i]=parseInt(outNumberString);
		}
		Array.getStatistics(outNumber, min, max, mean, stdDev);
		nextOut=max+1;
		outDir=File.getParent(inDir)+"\\"+File.getName(inDir)+"_OUT"+nextOut;
	}
	File.makeDirectory(outDir);

	//SLICE PROCESSING
	for (i=0; i<batchArray.length; i++) {
		if (fileCheckbox[i]==true) {
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
			}
			Array.sort(nd2Array);

			for (j=0; j<nd2Array.length; j++) {   //FOR loop to process all the files in inDir folder
				if (fileCheckbox[i]==true) {
					print("Processing the file: "+nd2Array[j]);
					path=inDir+File.separator+batchArray[i]+nd2Array[j];
					run("Bio-Formats", "open=["+path+"] autoscale color_mode=Grayscale rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
					rename(nd2Array[j]);
					currentFileName=File.nameWithoutExtension;
					if (mode=="Projections + Flat-field correction") {
						Stack.getDimensions(width, height, channels, slices, frames);
						flatFieldImages=newArray(channels);
						run("Split Channels");
						for (k=0; k<channels; k++) {
							flatFieldFile="Flat-field_C"+k+1+"_"+substring(batchArray[i], 0, lengthOf(batchArray[i]) - 1)+".tif";
							open(inDir+File.separator+batchArray[i]+flatFieldFile);
							flatFieldImages[k]=getTitle();
						}
						for (k=0; k<channels; k++) {
							imageCalculator("Divide stack", "C"+k+1+"-"+nd2Array[j], flatFieldImages[k]);
							close(flatFieldImages[k]);
						}
						run("Merge Channels...", "c1=C3-"+nd2Array[j]+" c2=C2-"+nd2Array[j]+" c3=C1-"+nd2Array[j]+" c4=C4-"+nd2Array[j]+" create");
						rename(nd2Array[j]);
					}
					run("Z Project...", "projection=[Sum Slices]");
					run("Split Channels");
					selectWindow(nd2Array[j]);
					run("Z Project...", "projection=[Max Intensity]");
					run("Split Channels");
					
					//channel 01
					selectWindow("C1-MAX_"+nd2Array[j]);
					run("Enhance Contrast...", "saturated=0.1 normalize");
					run("Subtract Background...", "rolling=15");
					title=getTitle();
					C1ImageID=getImageID();
					selectImage(C1ImageID);
					saveAs("Tiff", outDir+"\\"+title);
					close();
					
					//channel 02
					selectWindow("C2-SUM_"+nd2Array[j]);
					title=getTitle();
					C2ImageID=getImageID();
					selectImage(C2ImageID);
					saveAs("Tiff", outDir+"\\"+title);
					close();
					
					//channel 03
					selectWindow("C3-SUM_"+nd2Array[j]);
					title=getTitle();
					C3ImageID=getImageID();
					selectImage(C3ImageID);
					saveAs("Tiff", outDir+"\\"+title);
					close();
					
					//channel 04
					selectWindow("C4-SUM_"+nd2Array[j]);
					title=getTitle();
					C4ImageID=getImageID();
					selectImage(C4ImageID);
					saveAs("Tiff", outDir+"\\"+title);
					close("*");
				}
			}
			
			while (nImages>0) { 
				selectImage(nImages); 
			    close(); 
			}
			 
		}
	}
}
setBatchMode(false);
print("**** MACRO DONE ****");