import { Injectable } from '@angular/core';
import { Observable, Subject, Subscription } from 'rxjs';
import { webSocket, WebSocketSubject } from 'rxjs/webSocket';

import { FrameMessage, CameraResolution } from './frame-message';



export interface CameraSubject {
  kind: 'camera';
  cameraId: number;
  resolution: CameraResolution;
}

export interface AnalysisSubject {
  kind: 'analysis';
  analysisEngineId: number;
}

export type SubscriptionSubject = AnalysisSubject | CameraSubject;

@Injectable({
  providedIn: 'root'
})
export class VideoService {
  private subject: WebSocketSubject<Object>;
  private subscriberCount = 0;
  private subscription: Subscription;


  constructor() { }

  public connect(url?: string): WebSocketSubject<Object> {
    if (!url) {
      let parse = document.createElement('a');
      parse.href = document.querySelector('base')['href'];

      let loc = window.location;
      if (loc.protocol === "https:") {
        url = "wss:";
      } else {
        url = "ws:";
      }
      url += `//${parse.host}/${parse.pathname}/v1/ws_json`;
      console.log(`websocket url: ${url}`);
    }
    if (!this.subject) {
      this.subject = webSocket(url);
    }

    return this.subject;
  }

  private setupAcker() {
    if (this.subscriberCount == 0) {
      this.subscription = this.subject.subscribe(
        () => {
          this.subject.next('Ack');
        },
        () => { },
        () => { }
      );
    }
  }

  private cleanupAcker() {
    if (this.subscriberCount == 0 && this.subscription) {
      this.subscription.unsubscribe();
    }
  }

  public getObservable(subject: SubscriptionSubject): Observable<FrameMessage> {
    let frameSub: WebSocketSubject<FrameMessage> = this.subject as unknown as WebSocketSubject<FrameMessage>;

    return frameSub.multiplex(
      () => {
        this.setupAcker();
        this.subscriberCount++;
        switch (subject.kind) {
          case 'camera':
            return {
              'Subscribe': {
                'Camera': [subject.cameraId, subject.resolution],
              }
            }
        }
      },
      () => {
        this.subscriberCount--;
        this.cleanupAcker();
        switch (subject.kind) {
          case 'camera':
            return {
              'Unsubscribe': {
                'Camera': [subject.cameraId, subject.resolution],
              }
            }
        }
      },
      (m: FrameMessage): boolean => {
        switch (m.source.kind) {
          case 'camera':
            return subject.kind === 'camera'
              && subject.cameraId === m.source.cameraId
              && subject.resolution === m.resolution;
          case 'analysis':
            return subject.kind === 'analysis'
              && subject.analysisEngineId === m.source.analysisEngineId;
        }
      });
  }

  public getWriteSubject(): Subject<Object> {
    return this.subject;
  }
}
