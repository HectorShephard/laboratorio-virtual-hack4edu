"""One Euro (Casiez et al.) e histéresis, una instancia de cada uno por ID."""
import math


class OneEuro:
    def __init__(self, minimum=1.0, beta=3.0, derivative_cutoff=1.0):
        self.minimum, self.beta, self.derivative_cutoff = minimum, beta, derivative_cutoff
        self.reset()

    def reset(self):
        self.previous = self.filtered = self.derivative = None
        self.time = None

    @staticmethod
    def alpha(cutoff, dt):
        return 1.0 / (1.0 + 1.0 / (2 * math.pi * cutoff * dt))

    def update(self, values, now):
        values = list(values)
        if self.time is not None and now <= self.time:
            return list(self.filtered)
        if self.time is None:
            self.previous = self.filtered = values
            self.derivative = [0.0]*len(values)
        else:
            dt = max(.001, now-self.time)
            a = self.alpha(self.derivative_cutoff, dt)
            self.derivative = [a*(x-y)/dt+(1-a)*d for x,y,d in zip(values,self.previous,self.derivative)]
            cutoff = self.minimum+self.beta*math.sqrt(sum(d*d for d in self.derivative))
            a = self.alpha(cutoff, dt)
            self.filtered = [a*x+(1-a)*y for x,y in zip(values,self.filtered)]
            self.previous = values
        self.time = now
        return list(self.filtered)


class Pinch:
    def __init__(self, close=.35, release=.55):
        self.close, self.release = close, release
        self.reset()

    def reset(self):
        self.closed = self.candidate = False
        self.frames = 0

    def update(self, ratio):
        target = ratio < (self.release if self.closed else self.close)
        self.frames = self.frames+1 if target == self.candidate else 1
        self.candidate = target
        if self.frames >= 2:
            self.closed = target
        return self.closed
