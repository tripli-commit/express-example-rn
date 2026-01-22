import { NativeModules, NodeHandle, Platform } from 'react-native';
import { getSystemVersion } from 'react-native-device-info';
import ZegoExpressEngine, { ZegoPublishChannel, ZegoViewMode } from 'zego-express-engine-reactnative';

const { PipModule } = NativeModules;

export default class StreamHelper {
    static TAG = 'StreamHelper'

    static iosPipStreamID = ''

    static setIosPipStreamID = (streamID: string) => {
        console.log(this.TAG, `change iosPipStream: ${this.iosPipStreamID} => ${streamID}`)
        let hasChanged = false
        if (this.iosPipStreamID !== streamID && this.iosPipStreamID !== '') {
            this.stopPlayingStream(this.iosPipStreamID)
            hasChanged = true
        }
        this.iosPipStreamID = streamID
        return hasChanged;
    }

    static startPlayingStream = (streamID: string, reactTag: null | NodeHandle) => {
        if (Platform.OS === 'ios' 
            && this.isOsVersionGreaterOrEqualThan(15) 
            && streamID === this.iosPipStreamID)
        {
            console.log(this.TAG, `PipModule.startPlayingStream: ${streamID}`)
            PipModule.startPlayingStream(
                {streamID: streamID, reactTag: reactTag, viewMode: ZegoViewMode.AspectFill}
            )
        } else {
            console.log(this.TAG, `Express.startPlayingStream: ${streamID}`)
            ZegoExpressEngine.instance().startPlayingStream(
                streamID, 
                {"reactTag": reactTag, "viewMode": ZegoViewMode.AspectFill, "backgroundColor": 0},
                {}
            )
        }
    }
  
    static stopPlayingStream = (streamID: string) => {
        if (streamID.length == 0) {
            return;
        }
        
        if (Platform.OS === 'ios' 
            && this.isOsVersionGreaterOrEqualThan(15) 
            && streamID === this.iosPipStreamID)
        {
            console.log(this.TAG, `PipModule.stopPlayingStream: ${streamID}`)
            PipModule.stopPlayingStream({
                streamID: streamID
            })
            this.iosPipStreamID = ''
        } else {
            console.log(this.TAG, `Express.stopPlayingStream: ${streamID}`)
            ZegoExpressEngine.instance().stopPlayingStream(streamID);
        }
    }

    static startPreview = (reactTag: null | NodeHandle) => {
        if (Platform.OS === 'ios' && this.isOsVersionGreaterOrEqualThan(15)) {
            console.log(this.TAG, `PipModule.startPreview: ${reactTag}`)
            PipModule.startPreview({reactTag: reactTag, viewMode: ZegoViewMode.AspectFill})
        } else {
            console.log(this.TAG, `Express.startPreview: ${reactTag}`)
            ZegoExpressEngine.instance().startPreview(
                {"reactTag": reactTag, "viewMode": ZegoViewMode.AspectFill, "backgroundColor": 0}, 
                ZegoPublishChannel.Main
            );
        }
    }

    static stopPreview = () => {
        if (Platform.OS === 'ios' && this.isOsVersionGreaterOrEqualThan(15)) {
            console.log(this.TAG, `PipModule.stopPreview`)
            PipModule.stopPreview()
        } else {
            console.log(this.TAG, `Express.stopPreview`)
            ZegoExpressEngine.instance().stopPreview(ZegoPublishChannel.Main);
        }
    }

    static isOsVersionGreaterOrEqualThan = (compareVersion: number) => {
        const version = parseInt(getSystemVersion(), 10);
        return version >= compareVersion;
    };
}