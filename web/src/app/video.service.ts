import { Injectable } from '@angular/core';
import { Observable, Subject, Subscription } from 'rxjs';
import { webSocket, WebSocketSubject } from 'rxjs/webSocket';

import { FrameMessage } from './frame-message';

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

  public getObservable(cameraId: number, resolution: string): Observable<FrameMessage> {
    let frameSub: WebSocketSubject<FrameMessage> = this.subject as unknown as WebSocketSubject<FrameMessage>;

    return frameSub.multiplex(
      () => {
        this.setupAcker();
        this.subscriberCount++;
        return {
          'Subscribe': {
            'Camera': [cameraId, resolution],
          }
        }
      },
      () => {
        this.subscriberCount--;
        this.cleanupAcker();
        return {
          'Unsubscribe': {
            'Camera': [cameraId, resolution]
          }
        }
      },
      (m) => {
        return m.source.Camera === cameraId && m.resolution === resolution;
      }
    );
  }

  public getWriteSubject(): Subject<Object> {
    return this.subject;
  }
}
